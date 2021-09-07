using Test
using PkgJogger
using UUIDs
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

    # Load with JogPkgJogger
    @testset "Jogger's load_benchmarks" begin
        uuid = splitpath(file)[end] |> x -> split(x, ".")[1]
        r3 = JogPkgJogger.load_benchmarks(uuid)
        r4 = JogPkgJogger.load_benchmarks(UUID(uuid))
        @test r3 == r4
        @test r3["benchmarks"] == r
        @test r4["benchmarks"] == r
        @test r2 == r3 == r4

        # Check that we error for invalid uuids
        @test_throws AssertionError JogPkgJogger.load_benchmarks("not-a-uuid")
        @test_throws AssertionError JogPkgJogger.load_benchmarks(UUIDs.uuid4())
    end

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
end
