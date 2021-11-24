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
    suite_expressions = Expr[]
    for s in locate_benchmarks(bench_dir)
        suite_expr, suite_module = build_module(s)
        push!(suite_modules, suite_module)
        push!(suite_expressions, suite_expr)
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
                $(suite_expressions...)
                suite
            end

            """
                benchmark(; verbose = false, save = false)

            Warmup, tune and run the benchmarking suite for $($pkg).

            If `save = true`, will save the results using [`$($modname).save_benchmarks`](@ref)
            and display the filename using `@info`.
            """
            function benchmark(; verbose = false, save = false)
                s = suite()
                BenchmarkTools.warmup(s; verbose)
                BenchmarkTools.tune!(s; verbose = verbose)
                results = BenchmarkTools.run(s; verbose = verbose)
                if save
                    filename = save_benchmarks(results)
                    @info "Saved results to $filename"
                end
                return results
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

            Results can be loaded with [`PkgJogger.load_benchmarks(filename)`](@ref) or
            [`$($modname).load_benchmarks(uuid)`](@ref)
            """
            function save_benchmarks(results)
                filename = joinpath(BENCHMARK_DIR, "trial", "$(UUIDs.uuid4()).json.gz")
                PkgJogger.save_benchmarks(filename, results)
                filename
            end

            """
                load_benchmarks(filename::String)::Dict
                load_benchmarks(uuid::String)::Dict
                load_benchmarks(uuid::UUID)::Dict

            Loads benchmarking results for $($pkg) from `BENCHMARK_DIR/trial`
            """
            load_benchmarks(uuid::UUIDs.UUID) = load_benchmarks(string(uuid))
            function load_benchmarks(uuid::AbstractString)
                # Check if input is a filename
                isfile(uuid) && return PkgJogger.load_benchmarks(uuid)

                # Check if a valid benchmark uuid
                path = joinpath(BENCHMARK_DIR, "trial", uuid * ".json.gz")
                @assert isfile(path) "Missing benchmarking results for $uuid, expected path: $path"
                PkgJogger.load_benchmarks(path)
            end

            """
                judge(new, old; metric=Statistics.median, kwargs...)

            Compares benchmarking results from `new` vs `old` for regressions/improvements
            using `metric` as a basis. Additional `kwargs` are passed to `BenchmarkTools.judge`

            Identical to [`PkgJogger.judge`](@ref), but accepts UUIDs for `new` and `old`
            """
            function judge(new, old; kwargs...)
                PkgJogger.judge(_get_benchmarks(new), _get_benchmarks(old); kwargs...)
            end
            _get_benchmarks(b::AbstractString) = load_benchmarks(b)
            _get_benchmarks(b) = PkgJogger._get_benchmarks(b)
        end
    end
end

"""
    build_module(s::BenchModule)

Construct a module wrapping the BenchmarkGroup defined by `s::BenchModule`
"""
function build_module(s::BenchModule)
    modname = gensym(s.name[end])
    module_expr = quote
        module $modname
            __revise_mode__ = :eval
            include($(s.filename))
        end
        Revise.track($modname, $(s.filename))
    end

    # Build Expression for accessing suite
    suite_expr = quote
        suite[$(s.name)] = $(modname).suite
    end

    return suite_expr, module_expr
end
