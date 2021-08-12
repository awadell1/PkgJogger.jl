using Test
using PkgJogger
import BenchmarkTools

include("utils.jl")

@testset "canonical" begin
    @jog PkgJogger
    @test @isdefined JogPkgJogger

    # Run Benchmarks
    r = JogPkgJogger.benchmark()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

    # Warmup
    @test_nowarn JogPkgJogger.warmup()

    # Running
    r = JogPkgJogger.run()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

    # Saving and Loading
    file = PkgJogger.save_benchmarks(r)
    @test isfile(file)
    r2 = PkgJogger.load_benchmarks(file)
    test_loaded_results(r2)
    @test r == r2["benchmarks"]
end

@testset "Jogger Methods" begin
    @jog PkgJogger
    @test @isdefined JogPkgJogger

    @testset "JogPkgJogger.$f" for (m, f) in PkgJogger.DISPATCH_METHODS
        @test isdefined(JogPkgJogger, f)
    end
end
