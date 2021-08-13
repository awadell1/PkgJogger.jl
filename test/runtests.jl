using Test
using SafeTestsets
using PkgJogger

@testset "PkgJogger.jl" begin
    @safetestset "Smoke Tests" begin include("smoke.jl") end
    @safetestset "CI Workflow" begin include("ci.jl") end
end
