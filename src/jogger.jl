# This file contains functions related to building the JogPkgName module

# List of Module => function that `JogPkgName` will dispatch to
const DISPATCH_METHODS = [
    :BenchmarkTools => :run,
    :BenchmarkTools => :warmup,
    :PkgJogger => :benchmark
]

"""
    benchmark(s::BenchmarkGroup)

Warmup, tune and run a benchmark suite
"""
function benchmark(s::BenchmarkTools.BenchmarkGroup)
    warmup(s)
    tune!(s)
    BenchmarkTools.run(s)
end

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
    trial_dir = joinpath(bench_dir, "trial")

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

    # Dispatch to PkgJogger functions
    dispatch_funcs = Expr[]
    for (m, f) in DISPATCH_METHODS
        exp = quote
            $f(args...; kwargs...) = $(m).$(f)(suite(), args...; kwargs...)
        end
        push!(dispatch_funcs, exp)
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
                suite()

            Gets the BenchmarkTools suite for $($pkg)
            """
            function suite()
                suite = BenchmarkTools.BenchmarkGroup()
                for (n, m) in zip([$(string.(benchmarks)...)], [$(benchmarks...)])
                    suite[n] = m.suite
                end
                suite
            end

            """
                save_benchmarks(results)

            Saves benchmarking results for $($pkg) to $($trial_dir) with a
            unique filename. Returns path to saved results

            Results are saved as *.json.gz files and can be loaded using
            [`PkgJogger.load_benchmarks`](@ref)
            """
            function save_benchmarks(results)
                PkgJogger._save_jogger_benchmarks($trial_dir, results)
            end

            $(dispatch_funcs...)
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
