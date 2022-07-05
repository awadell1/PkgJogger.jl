# This file contains functions related to building the JogPkgName module

"""
    @jog PkgName

Creates a module named `JogPkgName` for running benchmarks for `PkgName`.

Most edits to benchmark files are correctly tracked by Revise.jl. If they are
not, re-run `@jog PkgName` to fully reload `JogPkgName`.

> Revise must be loaded before calling `@jog PkgName` in order for edits to be
> automatically tracked.

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
    if !isdir(bench_dir)
        error("No benchmark directory found for $pkg. Expected: $bench_dir")
    end

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

    # String representation of the Jogger module for use in doc strings
    mod_str = string(modname)

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

            # Dispatch calls to tune! here so we can use the jogger variant of load_benchmarks
            __tune!(group::BenchmarkTools.BenchmarkGroup, ref::BenchmarkTools.BenchmarkGroup; kwargs...) = PkgJogger.tune!(group, ref; kwargs...)
            __tune!(group::BenchmarkTools.BenchmarkGroup, ref; kwargs...) = PkgJogger.tune!(group, load_benchmarks(ref); kwargs...)
            __tune!(group::BenchmarkTools.BenchmarkGroup, ::Nothing; kwargs...) = BenchmarkTools.tune!(group; kwargs...)

            """
                benchmark(; verbose = false, save = false, ref = nothing)

            Warmup, tune and run the benchmarking suite for $($pkg).

            If `save = true`, will save the results using [`$($mod_str).save_benchmarks`](@ref)
            and display the filename using `@info`.

            To reuse prior tuning results set `ref` to a BenchmarkGroup or suitable identifier
            for [`$($mod_str).load_benchmarks`](@ref). See [`PkgJogger.tune!`](@ref) for
            more information about re-using tuning results.
            """
            function benchmark(; verbose = false, save = false, ref = nothing)
                s = suite()
                BenchmarkTools.warmup(s; verbose)
                __tune!(s, ref; verbose = verbose)
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

            Saves benchmarking results for $($pkg) to `BENCHMARK_DIR/trial/uuid4().bson.gz`,
            and returns the path to the saved results

            > Meta Data such as cpu load, time stamp, etc. are collected on save, not during
            > benchmarking. For representative metadata, results should be saved immediately
            > after benchmarking.

            Results can be loaded with [`PkgJogger.load_benchmarks`](@ref) or
            [`$($mod_str).load_benchmarks`](@ref)

            ## Example

            Running a benchmark suite and then saving the results

            ```julia
            r = $($mod_str).benchmark()
            filename = $($mod_str).save_benchmarks(r)
            ```

            > Equivalently: `$($mod_str).benchmark(; save = true)`

            """
            function save_benchmarks(results)
                filename = joinpath(BENCHMARK_DIR, "trial", "$(UUIDs.uuid4()).bson.gz")
                PkgJogger.save_benchmarks(filename, results)
                filename
            end

            """
                load_benchmarks(id)::Dict

            Loads benchmarking results for $($pkg) from `BENCHMARK_DIR/trial` based on `id`.
            The following are supported `id` types:

                - `filename::String`: Loads results from `filename`
                - `uuid::Union{String, UUID}`: Loads results with the given UUID
                - `:latest` loads the latest (By mtime) results from `BENCHMARK_DIR/trial`
                - `:oldest` loads the oldest (By mtime) results from `BENCHMARK_DIR/trial`
            """
            load_benchmarks(id) = PkgJogger.load_benchmarks(joinpath(BENCHMARK_DIR, "trial"), id)

            """
                judge(new, old; metric=Statistics.median, kwargs...)

            Compares benchmarking results from `new` vs `old` for regressions/improvements
            using `metric` as a basis. Additional `kwargs` are passed to `BenchmarkTools.judge`

            Identical to [`PkgJogger.judge`](@ref), but accepts any identifier supported by
            [`$($mod_str).load_benchmarks`](@ref)

            ## Examples

            ```julia
            # Judge the latest results vs. the oldest
            $($mod_str).judge(:latest, :oldest)
            [...]
            ```

            ```julia
            # Judge results by UUID
            $($mod_str).judge("$(UUIDs.uuid4())", "$(UUIDs.uuid4())")
            [...]
            ```

            ```julia
            # Judge using the minimum, instead of the median, time
            $($mod_str).judge("path/to/results.bson.gz", "$(UUIDs.uuid4())"; metric=minimum)
            [...]
            ```

            """
            function judge(new, old; kwargs...)
                PkgJogger.judge(_get_benchmarks(new), _get_benchmarks(old); kwargs...)
            end
            _get_benchmarks(b) = load_benchmarks(b)
            _get_benchmarks(b::Dict) = PkgJogger._get_benchmarks(b)
            _get_benchmarks(b::BenchmarkTools.BenchmarkGroup) = b

        end
    end
end

"""
    build_module(s::BenchModule)

Construct a module wrapping the BenchmarkGroup defined by `s::BenchModule`
"""
function build_module(s::BenchModule)
    # Generate a name for the benchmarking module
    modname = gensym(s.name[end])

    # If Revise.jl has been loaded, use it to track changes to the
    # benchmarking module. Otherwise, don't track changes.
    revise_id = PkgId(UUID("295af30f-e4ad-537b-8983-00126c2a3abe"), "Revise")
    if haskey(Base.loaded_modules, revise_id)
        revise_exp = :( Base.loaded_modules[$revise_id].track($modname, $(s.filename)) )
    else
        revise_exp = :()
    end

    module_expr = quote
        module $modname
            __revise_mode__ = :eval
            include($(s.filename))
        end
        $(revise_exp)
    end

    # Build Expression for accessing suite
    suite_expr = quote
        suite[$(s.name)] = $(modname).suite
    end

    return suite_expr, module_expr
end
