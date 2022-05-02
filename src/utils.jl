struct BenchModule
    filename::String
    name::Vector{String}
end

"""
    benchmark_dir(pkg::Module)
    benchmark_dir(pkg::PackageSpec)
    benchmark_dir(project_path::String)

Returns the absolute path of the benchmarks folder for `pkg`.

Supported Benchmark Directories:
- `PKG_DIR/benchmark`

"""
benchmark_dir(pkg::Module) = benchmark_dir(Base.PkgId(pkg))
benchmark_dir(pkg::Symbol) = benchmark_dir(Base.PkgId(string(pkg)))
function benchmark_dir(pkg_id::Base.PkgId)
    pkg_dir = joinpath(dirname(Base.locate_package(pkg_id)), "..")
    benchmark_dir(pkg_dir)
end
function benchmark_dir(pkg_dir::String)
    joinpath(pkg_dir, "benchmark") |> abspath
end
function benchmark_dir(pkg::Pkg.Types.PackageSpec)
    # Locate packages location from a PackageSpec
    if pkg.path !== nothing
        pkg_path = pkg.path
    elseif pkg.repo.source !== nothing
        pkg_path = pkg.repo.source
    else
        error("Unable to locate $pkg")
    end
    benchmark_dir(pkg_path)
end

"""
    locate_benchmarks(pkg::Module)
    locate_benchmarks(path::String, name=String[])

Returns a list of `BenchModule` for identified benchmark files
"""
function locate_benchmarks(path, name=String[])
    suite = BenchModule[]
    for file in readdir(path)
        # Check that path is named 'bench_*'
        !startswith(file, "bench_") && continue

        # Check if file is a valid target to add
        cur_name = [name..., file]
        filename = joinpath(path, file)
        if isfile(filename) && endswith(file, ".jl")
            # File is a julia file named bench_*.jl
            push!(suite, BenchModule(filename, cur_name))
        elseif isdir(filename)
            # Subdirectory named bench_* -> Look for more modules
            append!(suite, locate_benchmarks(filename, cur_name))
        end
    end
    return suite
end
locate_benchmarks(pkg::Module) = benchmark_dir(pkg) |> locate_benchmarks

"""
    judge(new, old; metric=Statistics.median, kwargs...)

Compares benchmarking results from `new` vs `old` for regressions/improvements
using `metric` as a basis. Additional `kwargs` are passed to `BenchmarkTools.judge`

Effectively a convenience wrapper around `load_benchmarks` and `BenchmarkTools.judge`

`new` and `old` can be any one of the following:
    - Filename of benchmarking results saved by PkgJogger
    - A `Dict` as returned by [`PkgJogger.load_benchmarks(filename)`](@ref)
    - A `BenchmarkTools.BenchmarkGroup` with benchmarking results
"""
function judge(
    new::BenchmarkTools.BenchmarkGroup,
    old::BenchmarkTools.BenchmarkGroup;
    metric = Statistics.median,
    kwargs...
)
    new_estimate = metric(new)
    old_estimate = metric(old)
    BenchmarkTools.judge(new_estimate, old_estimate; kwargs...)
end
function judge(new, old; kwargs...)
    new_results = _get_benchmarks(new)
    old_results = _get_benchmarks(old)
    judge(new_results, old_results; kwargs...)
end

_get_benchmarks(b::BenchmarkTools.BenchmarkGroup) = b
_get_benchmarks(b::Dict) =  b["benchmarks"]::BenchmarkTools.BenchmarkGroup
_get_benchmarks(filename::String) = load_benchmarks(filename) |> _get_benchmarks

"""
    test_benchmarks(s::BenchmarkGroup)

Runs a `@testsuite` for each benchmark in `s` once (One evaluation of the benchmark's target)
Sub-benchmark groups / benchmarks are recursively wrapped in `@testsuites` for easy
identification.

benchmarks are marked as "passing" if they don't error during evaluation.
"""
test_benchmarks(s::BenchmarkTools.BenchmarkGroup) = test_benchmarks("Testing Benchmarks", s)
function test_benchmarks(name, s::BenchmarkTools.BenchmarkGroup)
    @testset "$name" for (name, bench) in s
        test_benchmarks(name, bench)
    end
end
function test_benchmarks(name, b::BenchmarkTools.Benchmark)
    @testset "$name" begin
        run(b; verbose=false, samples=1, evals=1, gctrial=false, gcsample=false)
        @test true
    end
end

"""
    @test_benchmarks PkgName

Collects all benchmarks for `PkgName`, and test that they don't error when ran once.

## Example

```julia-repl
julia> using PkgJogger, Example

julia> @test_benchmarks Example
│ Test Summary:  | Pass  Total
│ bench_timer.jl |    2      2
[...]
```

## Testing

Each benchmark is wrapped in a `@testset`, run only once, and marked as passing iff no errors
are raised. This provides a fast smoke test for a benchmarking suite, and avoids the usual
cost of tunning, warming up and collecting samples accrued when actually benchmarking.

## Benchmark Loading

Locating benchmarks for testing is the same as for [`@jog`](@ref) and can be examined using
[`PkgJogger.locate_benchmarks`](@ref).
"""
macro test_benchmarks(pkg)
    quote
        jogger = @jog $pkg
        s = jogger.suite()
        PkgJogger.test_benchmarks(s)
    end
end

"""
    tune!(group::BenchmarkGroup, ref::BenchmarkGroup; verbose::Bool=false)

Tunes a BenchmarkGroup, only tunning benchmarks not found in `ref`, otherwise reuse tuning
results from the reference BenchmarkGroup, by copying over all benchmark parameters from `ref`.

Tunning is handled by `BenchmarkTools.tune!`

This can reduce benchmarking runtimes significantly by only tuning new benchmarks. But does
ignore the following:

- Changes to benchmarking parameters (ie. memory_tolerance) between `group` and `ref`
- Significant changes in performance, such that re-tunning is warranted
- Other changes (ie. changing machines), such that re-tunning is warranted

Benchmarks are in `group` and `ref` are matched after serializing their keys. This is to
support reusing tunes from a saved run. As the key `["bench_foo.jl", 0.1]` serializes to
`["bench_foo.jl", "0.1"]`. In order to avoid potential conflict, tuning results are only
used iff:

- `ref` has a key that serializes to a matching key (i.e. `["bench_foo.jl", "0.1"]`)
- No other key in `ref` or `group` serializes to the same key

> For example, If `ref` contained both `["bench_foo.jl", 0.1]` and `["bench_foo.jl", "0.1"]`, then
> neither would be used, as there is no way to distinguish between the two, post-serialization.
"""
function tune!(group::BenchmarkTools.BenchmarkGroup, ref::BenchmarkTools.BenchmarkGroup; kwargs...)
    # Get the benchmark trials from each set
    group_leaves  = _resolve_leaves(group)
    ref_leaves = _resolve_leaves(ref)

    # Only reuse tuning results that can be uniquely identified
    _injective!(group_leaves, ref_leaves)
    reuse_leave, retune_leaves = group_leaves
    ref_injective = first(ref_leaves)

    # Only reuse tuning results that can be uniquely identified
    for (k, v) in retune_leaves
        BenchmarkTools.tune!(v; kwargs...)
    end

    # Reuse tunning from prior benchmarks
    for (k, v) in reuse_leave
        v.params = copy(ref_injective[k].params)
    end

    return group
end

tune!(group::BenchmarkTools.BenchmarkGroup; kwargs...) = BenchmarkTools.tune!(group; kwargs...)
tune!(group::BenchmarkTools.BenchmarkGroup, ref; kwargs...) = tune!(group, load_benchmarks(ref); kwargs...)
tune!(group::BenchmarkTools.BenchmarkGroup, ref::Dict; kwargs...) = tune!(group, get(ref, "benchmarks", nothing); kwargs...)
tune!(group::BenchmarkTools.BenchmarkGroup, ::Nothing; kwargs...) = tune!(group; kwargs...)

"""
    injective, non_injective = _resolve_leaves(b::BenchmarkGroup)

Given a benchmark group, split it's leaves into an injective and non-injective set. Leaves
in the injective are can be uniquely identified after their key has been stringified

For example, `0.1` and `"0.2"` can be uniquely identified after being stringified `"0.1" !=
"0.2"`. But, `0.1` and `"0.1"` cannot be uniquely identified after being stringified `"0.1"
== "0.1"`.

This function splits the leaves into an injective set (Where stringifing doesn't result in
conflicts) and an non_injective set which does.
"""
function _resolve_leaves(group::BenchmarkTools.BenchmarkGroup)
    # Convert benchmark keys to vectors of strings
    bench_leaves = leaves(group)
    injective = Dict{Vector{String}, Any}()
    non_injective = Dict{Vector{String}, Vector{Any}}()
    for b in bench_leaves
        norm_key = string.(first(b))
        maybe_injective = !haskey(non_injective, norm_key)
        if !haskey(injective, norm_key) && maybe_injective
            # Unique mapping from key to string encoded key
            injective[norm_key] = last(b)
        else
            # If the key was previously injective, pop it from the injective set and
            # add it to the non-injective set
            if maybe_injective
                non_injective[norm_key] = [pop!(injective, norm_key)]
            end

            # And the new non-injective benchmark key
            push!(non_injective[norm_key], last(b))
        end
    end

    # Warn if any key is non-injective
    if !isempty(non_injective)
        @warn "Benchmark Keys are not-unique after serializing" keys(non_injective)
    end
    return injective, non_injective
end

function _injective!(a, b)
    a_inject, a_non_inject = a
    b_inject, b_non_inject = b

    # For each uniquely identifiable key in a, check if there is a unique item in b
    for key in keys(a_inject)
        if haskey(b_non_inject, key) || !haskey(b_inject, key)
            # Non-unique mapping from a -> b
            a_non_inject[key] = [pop!(a_inject, key)]
        end
    end
    return nothing
end

