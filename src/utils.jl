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
benchmark_dir(pkg::Module) = benchmark_dir(pkgdir(pkg))
function benchmark_dir(pkg::Symbol)
    pkg_id = Base.identify_package(string(pkg))
    @assert !isnothing(pkg_id) "Could not identify the package: $pkg"
    benchmark_dir(pkg_id)
end
function benchmark_dir(pkg_id::Base.PkgId)
    entry_point = Base.locate_package(pkg_id)
    @assert !isnothing(entry_point) "Could not locate the package: $pkg_id"
    pkg_dir = joinpath(entry_point, "..", "..")
    benchmark_dir(pkg_dir)
end
function benchmark_dir(pkg_dir::String)
    joinpath(pkg_dir, "benchmark") |> abspath
end
function benchmark_dir(pkg::Pkg.Types.PackageSpec)
    # Locate packages location from a PackageSpec
    if !isnothing(pkg.path)
        return benchmark_dir(pkg.path)
    elseif !isnothing(pkg.repo.source)
        return benchmark_dir(pkg.repo.source)
    elseif ~isnothing(pkg.name) && ~isnothing(pkg.uuid)
        return benchmark_dir(Base.PkgId(pkg.uuid, pkg.name))
    elseif ~isnothing(pkg.name)
        return benchmark_dir(Symbol(pkg.name))
    else
        error("Unable to locate $pkg")
    end
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

_SELECT_DOCS = """
"""
"""
    getsuite(suite, [select...])

$(_SELECT_DOCS)
"""
getsuite(suite::BenchmarkGroup) = suite
getsuite(suite::BenchmarkGroup, ::Colon) = suite
getsuite(suite::BenchmarkGroup, r::Regex) = filter(!isnothing ∘ Base.Fix1(match, r) ∘ first, suite)
getsuite(suite::BenchmarkGroup, f::BenchmarkTools.TagFilter) = suite[f]
getsuite(::BenchmarkTools.Benchmark, ::Any) = nothing
getsuite(suite::BenchmarkGroup, idx) = !haskey(suite, idx) ? BenchmarkGroup() : BenchmarkGroup(idx => suite[idx])
function getsuite(suite::BenchmarkGroup, idx, rest...)
    src = getsuite(suite, idx)
    dst = similar(src)
    for (k, v) in src
        v = getsuite(v, rest...)
        !isnothing(v) && !isempty(v) && setindex!(dst, v, k)
    end
    return dst
end

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
    metric=Statistics.median,
    kwargs...
)
    new_estimate = metric(new)
    old_estimate = metric(old)
    BenchmarkTools.judge(new_estimate, old_estimate; kwargs...)
end
function judge(new, old, select...; kwargs...)
    new_results = getsuite(_get_benchmarks(new), select...)
    old_results = getsuite(_get_benchmarks(old), select...)
    judge(new_results, old_results; kwargs...)
end

# Internal functions to handle extracting benchmark results from various types
_get_benchmarks(b::BenchmarkTools.BenchmarkGroup) = b
_get_benchmarks(filename::AbstractString) = _get_benchmarks(load_benchmarks(filename))
function _get_benchmarks(b::Dict)
    @assert haskey(b, "benchmarks") "Missing 'benchmarks' key in $b"
    return b["benchmarks"]::BenchmarkTools.BenchmarkGroup
end

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
        b.samplefunc(b.quote_vals, BenchmarkTools.Parameters(b.params; evals=1))
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

This can reduce benchmarking runtimes significantly by only tuning new benchmarks. But does
ignore the following:
    - Changes to benchmarking parameters (ie. memory_tolerance) between `group` and `ref`
    - Significant changes in performance, such that re-tunning is warranted
    - Other changes (ie. changing machines), such that re-tunning is warranted
"""
function tune!(group::BenchmarkTools.BenchmarkGroup, ref::BenchmarkTools.BenchmarkGroup; pad="", kwargs...)
    for (k, v) in group
        if haskey(ref, k)
            # Load tuning parameters from reference
            tune!(v, ref[k]; kwargs...)
        else
            # Fallback to re-tuning the benchmark
            tune!(v; kwargs...)
        end
    end
    return group
end

# Fallback to using BenchmarkTools's tuning if no reference is provided
tune!(group::BenchmarkTools.BenchmarkGroup, ::Nothing; kwargs...) = tune!(group; kwargs...)
tune!(b; kwargs...) = BenchmarkTools.tune!(b; kwargs...)

# If ref is not a BenchmarkGroup, attempt to get it based on the type
tune!(group::BenchmarkTools.BenchmarkGroup, ref; kwargs...) = tune!(group, _get_benchmarks(ref); kwargs...)

# Load tuning results from the reference benchmarking results
function tune!(b::BenchmarkTools.Benchmark, ref; kwargs...)
    p = ref isa BenchmarkTools.Parameters ? ref : BenchmarkTools.params(ref)
    BenchmarkTools.loadparams!(b, p, :evals, :samples)
end
