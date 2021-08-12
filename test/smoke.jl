using Test
using PkgJogger
import BenchmarkTools

benchmark_dir = PkgJogger.benchmark_dir(PkgJogger)

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
    @test haskey(r2, "julia")
    @test haskey(r2, "manifest")
    @test haskey(r2, "benchmarks")
    @test r == r2
end

@testset "Jogger Methods" begin
    @jog PkgJogger
    @test @isdefined JogPkgJogger

    @testset "JogPkgJogger.$f" for (m, f) in PkgJogger.DISPATCH_METHODS
        @test isdefined(JogPkgJogger, f)
    end
end
