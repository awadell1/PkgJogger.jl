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

    # BENCHMARK_DIR
    @test JogPkgJogger.BENCHMARK_DIR == PkgJogger.benchmark_dir(PkgJogger)

    # Saving and Loading
    file = JogPkgJogger.save_benchmarks(r)
    @test isfile(file)
    r2 = PkgJogger.load_benchmarks(file)
    test_loaded_results(r2)
    @test r == r2["benchmarks"]

    # If this is a git repo, there should be a git entry
    if isdir(joinpath(PKG_JOGGER_PATH, ".git"))
        @test r2["git"] !== nothing
    end

    # Test results location
    trial_dir = joinpath(JogPkgJogger.BENCHMARK_DIR, "trial")
    test_subfile(trial_dir, file)

    # Clean up file and delete benchmark folder in test
    rm(file)
    rm(joinpath(@__DIR__, "benchmark"); force=true, recursive=true)
end

@testset "Jogger Methods" begin
    @jog PkgJogger
    @test @isdefined JogPkgJogger

    @testset "JogPkgJogger.$f" for (m, f) in PkgJogger.DISPATCH_METHODS
        @test isdefined(JogPkgJogger, f)
    end
end
