@testitem "canonical" setup=[ExamplePkg, BenchmarkTests] begin
    using PkgJogger
    import Test
    import UUIDs
    import BenchmarkTools

    # Create a jogger
    Example, cleanup = create_example()
    eval(Expr(:macrocall, Symbol("@jog"), LineNumberNode(@__LINE__, @__FILE__), Example))
    JogExample = getproperty(@__MODULE__, Symbol(:Jog, Example))

    # Run Benchmarks
    r = JogExample.benchmark()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

    # Running
    r = JogExample.run()
    @test typeof(r) <: BenchmarkTools.BenchmarkGroup

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
        r4 = JogExample.load_benchmarks(UUIDs.UUID(uuid))
        r5 = JogExample.load_benchmarks(:latest)
        @test results_match(r2, r3)
        @test results_match(r3, r4)
        @test results_match(r4, r5)
        @test r3["benchmarks"] == r
        @test r4["benchmarks"] == r

        # Check that we error for invalid uuids
        @test_throws ErrorException JogExample.load_benchmarks("not-a-uuid")
        @test_throws ErrorException JogExample.load_benchmarks(UUIDs.uuid4())
        @test_throws MethodError JogExample.load_benchmarks(:not_a_valid_option)
    end

    # Test Retuning
    @testset "Reusing tune! results" begin
        test_benchmark(JogExample.benchmark(ref = r), r)
        test_benchmark(JogExample.benchmark(ref = get_uuid(file)), r)
        test_benchmark(JogExample.benchmark(ref = file), r)
        test_benchmark(JogExample.benchmark(ref = :latest), r)
        test_benchmark(JogExample.benchmark(ref = :oldest), r)
    end

    # Test Judging
    @test_nowarn JogExample.judge(file, file)

    # Test results location
    trial_dir = joinpath(JogExample.BENCHMARK_DIR, "trial")
    test_subfile(trial_dir, file)

    # Clean up file and delete benchmark folder in test
    rm(file)
    rm(joinpath(@__DIR__, "benchmark"); force=true, recursive=true)

    # Test @test_benchmarks
    @testset "test_benchmarks" begin
        ts = eval(Expr(
            :macrocall,
            Symbol("@test_benchmarks"),
            LineNumberNode(@__LINE__, @__FILE__),
            Example
        ))
        @test ts isa Vector
        @test all(map(x -> x isa Test.AbstractTestSet, ts))
    end

    # No Benchmarks
    @test_throws LoadError @eval(@jog PkgJogger)

    cleanup()
end

@testitem "benchmark and save" setup=[ExamplePkg, BenchmarkTests] begin
    using PkgJogger
    using Test
    Example, cleanup = ExamplePkg.create_example()
    eval(Expr(:macrocall, Symbol("@jog"), LineNumberNode(@__LINE__, @__FILE__), Example))
    JogExample = getproperty(@__MODULE__, Symbol(:Jog, Example))

    logger = Test.TestLogger()
    Test.with_logger(logger) do
        JogExample.benchmark(save = true)
    end

    # Check that the filename is logged
    @test length(logger.logs) == 1
    @test startswith(logger.logs[1].message, "Saved results to ")

    # Check that the results are saved
    filename = match(r"\S*$", logger.logs[1].message).match
    r = PkgJogger.load_benchmarks(filename)
    test_loaded_results(r)

    # Check that :latest and :oldest returns the same results
    # Currently only have one result Saved
    r_latest = JogExample.load_benchmarks(:latest)
    r_oldest = JogExample.load_benchmarks(:oldest)
    @test results_match(r, r_latest) && results_match(r, r_oldest)

    # Check that :latest and :oldest return different results
    # Now have two results saved, so :latest and :oldest should return different results
    # Underlying benchmarks should still be the same, as we are using the same results
    JogExample.save_benchmarks(r["benchmarks"])
    r_latest = JogExample.load_benchmarks(:latest)
    r_oldest = JogExample.load_benchmarks(:oldest)
    @test !results_match(r, r_latest)
    @test results_match(r, r_oldest)
    cleanup()
end
