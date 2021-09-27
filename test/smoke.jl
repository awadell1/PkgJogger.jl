using Test
using Test: TestLogger
using Logging: with_logger
using PkgJogger
using UUIDs
using Example
import BenchmarkTools

include("utils.jl")

@testset "canonical" begin
    @jog Example
    @test @isdefined JogExample

    # Run Benchmarks
    r = JogExample.benchmark()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

    # Warmup
    @test_nowarn JogExample.warmup()

    # Running
    r = JogExample.run()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

    # BENCHMARK_DIR
    @test JogExample.BENCHMARK_DIR == PkgJogger.benchmark_dir(Example)

    # Saving and Loading
    file = JogExample.save_benchmarks(r)
    @test isfile(file)
    r2 = PkgJogger.load_benchmarks(file)
    test_loaded_results(r2)
    @test r == r2["benchmarks"]

    # Load with JogExample
    @testset "Jogger's load_benchmarks" begin
        uuid = get_uuid(file)
        r3 = JogExample.load_benchmarks(uuid)
        r4 = JogExample.load_benchmarks(UUID(uuid))
        @test r3 == r4
        @test r3["benchmarks"] == r
        @test r4["benchmarks"] == r
        @test r2 == r3 == r4

        # Check that we error for invalid uuids
        @test_throws AssertionError JogExample.load_benchmarks("not-a-uuid")
        @test_throws AssertionError JogExample.load_benchmarks(UUIDs.uuid4())
    end

    # Test Retuning
    @testset "Reusing tune! results" begin
        test_benchmark(JogExample.benchmark(ref = r), r)
        test_benchmark(JogExample.benchmark(ref = get_uuid(file)), r)
        test_benchmark(JogExample.benchmark(ref = file), r)
    end

    # Test Judging
    @test_nowarn JogExample.judge(file, file)

    # If this is a git repo, there should be a git entry
    if isdir(joinpath(PKG_JOGGER_PATH, ".git"))
        @test r2["git"] !== nothing
    end

    # Test results location
    trial_dir = joinpath(JogExample.BENCHMARK_DIR, "trial")
    test_subfile(trial_dir, file)

    # Clean up file and delete benchmark folder in test
    rm(file)
    rm(joinpath(@__DIR__, "benchmark"); force=true, recursive=true)

    # Test @test_benchmarks
    @testset "test_benchmarks" begin
        ts = @test_benchmarks Example
        @test ts isa Vector
        @test all(map(x -> x isa Test.AbstractTestSet, ts))
    end

    # No Benchmarks
    @test_throws LoadError @eval(@jog PkgJogger)
end

@testset "benchmark and save" begin
    @jog Example
    @test @isdefined JogExample

    logger = TestLogger()
    with_logger(logger) do
        JogExample.benchmark(save = true)
    end

    # Check that the filename is logged
    @test length(logger.logs) == 1
    @test startswith(logger.logs[1].message, "Saved results to ")

    # Check that the results are saved
    filename = match(r"\S*$", logger.logs[1].message).match
    r = PkgJogger.load_benchmarks(filename)
    test_loaded_results(r)
end
