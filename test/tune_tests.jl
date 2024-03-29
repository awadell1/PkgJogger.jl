@testsetup module TestTune
using Test
using BenchmarkTools
export random_tune, random_tune!, test_tune
macro test_tune(s, ref)
    quote
        s = $(esc(s))
        ref = $(esc(ref))
        s_keys = collect(keys(s))
        ref_keys = collect(keys(ref))
        @test isempty(setdiff(s_keys, ref_keys))
        for ((k1, v1), (k2, v2)) in zip(BenchmarkTools.leaves(s), BenchmarkTools.leaves(ref))
            @test v1.params.evals == v2.params.evals
        end
    end
end

function random_tune(suite)
    rsuite = deepcopy(suite)
    random_tune!(rsuite)
    return rsuite
end

function random_tune!(suite)
    for (_, b) in BenchmarkTools.leaves(suite)
        b.params.evals = rand(1:typemax(Int))
    end
    return suite
end
end

@testitem "unit tests" setup=[ExamplePkg, TestTune] begin
    using Test
    using BenchmarkTools
    using PkgJogger

    # Create Reference Tune
    jogger, cleanup = ExamplePkg.create_jogger()
    ref_suite = () -> deepcopy(jogger.suite())
    ref_tune = ref_suite()
    tune!(ref_tune)

    @testset "Fall back to BenchmarkTools.tune!" begin
        TestTune.@test_tune PkgJogger.tune!(ref_suite()) ref_tune
        TestTune.@test_tune PkgJogger.tune!(ref_suite(), nothing) ref_tune
        @test_throws AssertionError PkgJogger.tune!(ref_suite(), Dict())
    end

    @testset "Reuse prior tune" begin
        rand_tune = random_tune(ref_tune)
        TestTune.@test_tune PkgJogger.tune!(ref_suite(), rand_tune) rand_tune
        TestTune.@test_tune PkgJogger.tune!(ref_suite(), Dict("benchmarks" => rand_tune)) rand_tune
    end

    @testset "Partial Tune" begin
        # Create a suite with a new benchmark
        new_suite = ref_suite()
        new_suite["bench_tune.jl"] = deepcopy(first(new_suite)[2])

        # Create a random tune of the reference
        rand_tune = random_tune(ref_suite())

        # Expect the reference to be unchanged, and the new benchmark to be tuned
        expected_tune = deepcopy(rand_tune)
        expected_tune["bench_tune.jl"] = deepcopy(new_suite["bench_tune.jl"])
        tune!(expected_tune["bench_tune.jl"])

        TestTune.@test_tune PkgJogger.tune!(new_suite, rand_tune) expected_tune
    end

    @testset "Missing Tune" begin
        # Re-tune using an empty suite -> Everything should be tuned
        @testset "Empty Suite" begin
            new_suite = random_tune(ref_suite())
            ref = BenchmarkGroup()
            TestTune.@test_tune PkgJogger.tune!(new_suite, ref) ref_tune
        end

        # Retune using a missing benchmark -> Only it should be tuned
        @testset "Missing Reference Benchmark" begin
            new_suite = random_tune(ref_suite())
            ref = random_tune(ref_suite())

            # Add a new benchmark to new_suite to be tunned
            n, b = first(BenchmarkTools.leaves(new_suite))
            n[end] = rand()
            new_suite[n] = deepcopy(b)

            # Everything except the new benchmark should be tuned
            r = PkgJogger.tune!(new_suite, ref)
            TestTune.@test_tune r[ref] ref
        end
    end

    @testset "Ignore additional tunes" begin
        # Random Tune with additional benchmarks
        rand_tune = ref_suite()
        random_tune!(rand_tune)
        expected_tune = deepcopy(rand_tune)
        rand_tune["bench_tune.jl"] = deepcopy(first(rand_tune)[2])

        TestTune.@test_tune PkgJogger.tune!(ref_suite(), rand_tune) expected_tune
        TestTune.@test_tune PkgJogger.tune!(ref_suite(), Dict("benchmarks" => rand_tune)) expected_tune
    end

    cleanup()
end
