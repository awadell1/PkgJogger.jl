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
    @info suite
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
