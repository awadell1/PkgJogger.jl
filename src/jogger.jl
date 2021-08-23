# This file contains functions related to building the JogPkgName module

"""
    @jog PkgName

Creates a module named `JogPkgName` for running benchmarks for `PkgName`.

Most edits to benchmark files are correctly tracked by Revise.jl. If they are
not, re-run `@jog PkgName` to fully reload `JogPkgName`.

## Methods

- `suite`       Return a `BenchmarkGroup` of the benchmarks for `PkgName`
- `benchmark`   Warmup, tune and run the suite
- `run`         Dispatch to `BenchmarkTools.run(suite(), args...; kwargs...)`
- `warmup`      Dispatch to `BenchmarkTools.warmup(suite(), args...; kwargs...)`
- `save_benchmarks`     Save benchmarks for `PkgName` using an unique filename

## Isolated Benchmarks

Each benchmark file, is wrapped in it's own module preventing code loaded in one
file from being visible in another (unless explicitly included).

## Example

```julia
using AwesomePkg, PkgJogger
@jog AwesomePkg
results = JogAwesomePkg.benchmark()
file = JogAwesomePkg.save_benchmarks(results)
```
"""
macro jog(pkg)
    # Module Name
    modname = Symbol(:Jog, pkg)

    # Locate benchmark folder
    bench_dir = benchmark_dir(pkg)

    # Generate Using Statements
    using_statements = Expr[]
    for pkg in JOGGER_PKGS
        pkgname = Symbol(pkg.name)
        push!(using_statements, :(const $pkgname = Base.loaded_modules[$pkg]))
    end

    # Generate modules
    suite_modules = Expr[]
    benchmarks = Symbol[]
    for (name, file) in locate_benchmarks(bench_dir)
        push!(suite_modules, build_module(name, file))
        push!(benchmarks, Symbol(name))
    end

    # Flatten out modules into a Vector{Expr}
    if !isempty(suite_modules)
        suite_exp = getfield(MacroTools.flatten(quote $(suite_modules...) end), :args)
    else
        suite_exp = Expr[]
    end

    # Generate Module for Jogging pkg
    quote
        @eval module $modname
            using $pkg
            $(using_statements...)

            # Set Revise Mode and put submodules here
            __revise_mode__ = :eval
            $(suite_exp...)

            """
            BENCHMARK_DIR

            Directory of benchmarks for $($pkg)
            """
            const BENCHMARK_DIR = $bench_dir

            """
                suite()::BenchmarkGroup

            The BenchmarkTools suite for $($pkg)
            """
            function suite()
                suite = BenchmarkTools.BenchmarkGroup()
                for (n, m) in zip([$(string.(benchmarks)...)], [$(benchmarks...)])
                    suite[n] = m.suite
                end
                suite
            end

            """
                benchmark(; verbose = false)

            Warmup, tune and run the benchmarking suite for $($pkg)
            """
            function benchmark(; verbose = false)
                s = suite()
                BenchmarkTools.warmup(s; verbose)
                BenchmarkTools.tune!(s; verbose = verbose)
                BenchmarkTools.run(s; verbose = verbose)
            end

            """
                run(args...; verbose::Bool = false, kwargs)

            Run the benchmarking suite for $($pkg). See
            [`BenchmarkTools.run`](https://juliaci.github.io/BenchmarkTools.jl/stable/reference/#Base.run)
            for more options
            """
            function run(args...; verbose = false, kwargs...)
                BenchmarkTools.run(suite(), args...; verbose = verbose, kwargs...)
            end

            """
                warmup(; verbose::Bool = false)

            Warmup the benchmarking suite for $($pkg)
            """
            function warmup(; verbose = false)
                BenchmarkTools.warmup(suite(); verbose)
            end

            """
                save_benchmarks(results::BenchmarkGroup)::String

            Saves benchmarking results for $($pkg) to `BENCHMARK_DIR/trial/uuid4().json.gz`.

            Returns the path to the saved results

            Results can be loaded with [`PkgJogger.load_benchmarks(filename)`](@ref)
            """
            function save_benchmarks(results)
                filename = joinpath(BENCHMARK_DIR, "trial", "$(UUIDs.uuid4()).json.gz")
                PkgJogger.save_benchmarks(filename, results)
                filename
            end
        end
    end
end

"""
    build_module(name, file)

Construct a module wrapping the BenchmarkGroup defined by `file` with `name`
"""
function build_module(name, file)
    modname = Symbol(name)
    exp = quote
        module $modname
            __revise_mode__ = :eval
            include($file)
        end
        Revise.track($modname, $file)
    end
end
