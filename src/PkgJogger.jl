module PkgJogger

using MacroTools
using BenchmarkTools

export @jog

macro jog(pkg)
    # Module Name
    modname = Symbol(:Jog, pkg)

    # Locate benchmark folder
    bench_dir = @eval benchmark_dir($pkg)

    # Generate modules
    suite_modules = Expr[]
    benchmarks = Symbol[]
    for (name, file) in locate_benchmarks(bench_dir)
        push!(suite_modules, build_module(name, file))
        push!(benchmarks, Symbol(name))
    end

    # Dispatch to PkgJogger functions
    dispatch_funcs = Expr[]
    for (m, f) in [(:BenchmarkTools, :run), (:BenchmarkTools, :warmup), (:PkgJogger, :benchmark)]
        exp = quote
            $f(args...; kwargs...) = $(m).$(f)(suite(), args...; kwargs...)
        end
        push!(dispatch_funcs, exp)
    end

    # Flatten out modules into a Vector{Expr}
    suite_exp = getfield(MacroTools.flatten(quote $(suite_modules...) end), :args)

    # Generate Module for Jogging pkg
    quote
        @eval module $modname
            using $pkg
            using BenchmarkTools
            using PkgJogger
            using Revise

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

            $(dispatch_funcs...)
        end
    end
end

"""
    benchmark_dir(pkg)

Expected location of benchmarks for `pkg`
"""
function benchmark_dir(pkg::Module)
    pkg_dir = joinpath(dirname(pathof(pkg)), "..")
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


"""
    benchmark(s::BenchmarkGroup)

Warmup, tune and run a benchmark suite
"""
function benchmark(s::BenchmarkTools.BenchmarkGroup; kwargs...)
    warmup(s)
    tune!(s)
    BenchmarkTools.run(s)
end


end
