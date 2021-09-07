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

    # Run the rest of the unit testing suite
    @safetestset "Smoke Tests" begin include("smoke.jl") end
    @safetestset "Judging" begin include("judging.jl") end
    @safetestset "CI Workflow" begin include("ci.jl") end
end
