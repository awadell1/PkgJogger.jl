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

Compare benchmarking results to the latest saved results
```julia
results = JogAwesomePkg.benchmark()
JogAwesomePkg.judge(results, :latest)
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

    # Strip redundant quote blocks and flatten modules into a single single Vector{Expr}`
    # This is needed to avoid wrapping module blocks in `begin .. end` blocks
    suite_exp = mapreduce(Base.Fix2(getfield, :args), vcat, suite_modules)

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

        Directory of where benchmarking results are saved for $($pkg)
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
            suite(select...)

        Returns the benchmarking suite for $($pkg), optionally filtering based on `select...`.
        At it's simplest, `$($mod_str).suite(a, b, ...)` is equivalent to `$($mod_str).suite()[a][b]...`

        ## Supported Indices

        - `:` - Accepts any entry at that level in the tree
        - `r"Regexp"` - Accepts any entry matching the regular-expression
        - `key::Any` - Accepts any entry with a matching `key`
        - `@tagged` - Filters the suite to only include `BenchmarkGroup`s with a matching tag.
        See [Indexing into a BenchmarkGroup using @tagged](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/#Indexing-into-a-BenchmarkGroup-using-@tagged)

        !!! warning
            An entry in `suite` must match all indices to be returned. For example,
            `$($mod_str).suite(:, "bar")` would exclude a benchmark at `suite["bat"]` as
            the benchmark isn't matched by **both** `:` and `"bar"`.

        ## Examples
        - The suite in `bench_foo.jl`: `$($mod_str).suite("bench_foo.jl")`
        - Any benchmark matching `r"feature"` in any `bench_*.jl`: `$($mod_str).suite(:, r"feature")`

        """
        suite(select...) = PkgJogger.getsuite(suite(), select...)

        # Dispatch calls to tune! here so we can use the jogger variant of load_benchmarks
        __tune!(group::BenchmarkTools.BenchmarkGroup, ref::BenchmarkTools.BenchmarkGroup; kwargs...) = PkgJogger.tune!(group, ref; kwargs...)
        __tune!(group::BenchmarkTools.BenchmarkGroup, ref; kwargs...) = PkgJogger.tune!(group, load_benchmarks(ref); kwargs...)
        __tune!(group::BenchmarkTools.BenchmarkGroup, ::Nothing; kwargs...) = BenchmarkTools.tune!(group; kwargs...)

        """
            benchmark([select...]; verbose = false, save = false, ref = nothing)

        Warmup, tune and run the benchmarking suite for $($pkg).

        If `save = true`, will save the results using [`$($mod_str).save_benchmarks`](@ref)
        and display the filename using `@info`.

        To reuse prior tuning results set `ref` to a BenchmarkGroup or suitable identifier
        for [`$($mod_str).load_benchmarks`](@ref). See [`PkgJogger.tune!`](@ref) for
        more information about re-using tuning results.

        Optionally, benchmark a subset of the full suite by providing a set of filters.
        See [`PkgJogger.getsuite`](@ref) for more information.
        """
        function benchmark(select...; verbose=false, save=false, ref=nothing)
            s = suite(select...)
            __tune!(s, ref; verbose=verbose)
            results = BenchmarkTools.run(s; verbose=verbose)
            if save
                filename = save_benchmarks(results)
                @info "Saved results to $filename"
            end
            return results
        end

        """
            run([select...]; verbose::Bool = false, kwargs)

        Run the benchmarking suite for $($pkg). See
        [`BenchmarkTools.run`](https://juliaci.github.io/BenchmarkTools.jl/stable/reference/#Base.run)
        for more options

        Optionally, run a subset of the full suite by providing a set of filters.
        See [`PkgJogger.getsuite`](@ref) for more information.
        """
        function run(select...; verbose=false, kwargs...)
            BenchmarkTools.run(suite(select...); verbose=verbose, kwargs...)
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

        ## Examples

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
            judge(new, old, [select...]; metric=Statistics.median, kwargs...)

        Compares benchmarking results from `new` vs `old` for regressions/improvements
        using `metric` as a basis. Additional `kwargs` are passed to `BenchmarkTools.judge`

        Optionally, filter results using `select...`, see [`$($mod_str).suite`](@ref) for
        details.

        Identical to [`PkgJogger.judge`](@ref), but accepts any identifier supported by
        [`$($mod_str).load_benchmarks`](@ref)

        ## Examples

        ```julia
        # Judge the latest results vs. the oldest
        $($mod_str).judge(:latest, :oldest)
        [...]
        ```

        ```julia
        # Only judge results in `bench_foo.jl`
        $($mod_str).judge(:latest, :oldest, "bench_foo.jl")
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
        function judge(new, old, select...; kwargs...)
            PkgJogger.judge(_get_benchmarks(new), _get_benchmarks(old), select...; kwargs...)
        end
        _get_benchmarks(b) = load_benchmarks(b)
        _get_benchmarks(b::Dict) = PkgJogger._get_benchmarks(b)
        _get_benchmarks(b::BenchmarkTools.BenchmarkGroup) = b

        """
            profile(select...; profiler=:cpu, verbose=false, ref=nothing, kwargs...)

        Profile the benchmarking suite using the given `profiler`, the benchmark is
        warmed up, tuned and then ran under the profile.

        Like [`$($mod_str).benchmark`](@ref), `ref` can be used to reuse the results
        of a prior run during tuning.

        Some profilers support additional keyword arguments, see below for details.

        !!! info
            At this time, `PkgJogger` only supports profiling a single benchmark
            at a time. Automated saving is not supported.

        ## Available Profilers
        The following profilers have been implemented, but may not be currently
        loaded (See [Loaded Profilers](#loaded-profilers)).

        - `:cpu` - loaded by default
        - `:allocs` - loaded if `Profile.Allocs` exists (>=v1.8)
        - `:cuda` - loaded if the CUDA and NVTX packages are loaded

        ## Loaded Profilers
        The following profilers are currently loaded. Additional profilers
        are available via package extensions.

        $(@doc PkgJogger.profile)

        ---

        !!! info
            This list was generated on jogger creation (`@jog $($pkg)`),
            and my not reflect all loaded extensions. See [`PkgJogger.profile`](@ref)
            or regenerate the jogger for additional information

        """
        function profile(select...; profiler::Symbol=:cpu, kwargs...)
            s = suite(select...)
            PkgJogger.profile(s, profiler; kwargs...)
        end

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
        revise_exp = :(Base.loaded_modules[$revise_id].track($modname, $(s.filename)))
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
