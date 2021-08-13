# This file contains functions related to building the JogPkgName module

"""
    @jog PkgName

Creates a module named `JogPkgName` of benchmarks for `PkgName` pulled from
`PKG_DIR/benchmark/bench_*.jl`

Methods:
 - `suite()`        Return a `BenchmarkGroup` of the benchmarks for `PkgName`
 - `benchmark()`    Warmup, tune and run the suite
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
        push!(using_statements, :(using $pkgname))
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
                suite()

            Gets the BenchmarkTools suite for $($pkg)
            """
            function suite()
                suite = BenchmarkGroup()
                for (n, m) in zip([$(string.(benchmarks)...)], [$(benchmarks...)])
                    suite[n] = m.suite
                end
                suite
            end

            """
                save_benchmarks(results)

            Saves benchmarking results for $($pkg) to $($trial_dir)

            Results are saved as *.json.gz files and can be loaded using
            [`PkgJogger.load_benchmarks`](@ref PkgJogger.load_benchmarks)
            """
            function save_benchmarks(results)
                PkgJogger._save_jogger_benchmarks($bench_dir, results)
            end

            $(dispatch_funcs...)
        end
    end
end

"""
    benchmark_dir(pkg)

Expected location of benchmarks for `pkg`
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


function locate_benchmarks(dir)
    suite = Dict{String, String}()
    for file in readdir(dir; join=true)
        m = match(r"bench_(.*?)\.jl$", file)
        if m !== nothing
            suite[m.captures[1]] = file
        end
    end
    suite
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
