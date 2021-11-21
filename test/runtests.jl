using Test
using SafeTestsets
using PkgJogger

@testset "PkgJogger.jl" begin
    # Check that all modules listed in PkgJogger.JOGGER_PKGS are loaded
    # Do this first so later loadings don't pollute loaded_modules
    @testset "Loaded Modules" begin
        @testset "Check $(m.name) was loaded" for m in PkgJogger.JOGGER_PKGS
            @test haskey(Base.loaded_modules, m)
        end
    end

    # Load Example
    example_path = joinpath(@__DIR__, "Example.jl")
    if example_path ∉ LOAD_PATH
        push!(LOAD_PATH, example_path)
    end

    # Run the rest of the unit testing suite
    @safetestset "Smoke Tests" begin include("smoke.jl") end
    @safetestset "Judging" begin include("judging.jl") end
    @safetestset "CI Workflow" begin include("ci.jl") end
    @safetestset "Locate Benchmarks" begin include("locate_benchmarks.jl") end
    @safetestset "Doc Tests" begin
        using PkgJogger
        using Documenter
        doctest(PkgJogger)
    end
end
