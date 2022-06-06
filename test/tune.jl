using Test
using BenchmarkTools
using PkgJogger
using Example

include("utils.jl")

#@testset "smoke" begin
#    # Set up jogger with default example suite
#    jogger = @eval @jog Example
#
#    # Reuse the same tune for all benchmarks
#    ref = jogger.run()
#    @testset "from BenchmarkGroup" begin
#        @test_nowarn jogger.benchmark(; ref = ref)
#    end
#
#    # Repeat but load the tune from a file
#    trial = jogger.save_benchmarks(ref)
#    @testset "from disk" begin
#        @test_nowarn jogger.benchmark(; ref = trial)
#    end
#    rm(trial)
#
#    # Repeat, but tune the new benchmarks
#    @testset "partial tune!" begin
#        suite, cleanup = add_benchmark(Example, "bench_foo_$(rand(UInt16)).jl")
#        jogger_new = @eval @jog Example
#        r = @test_nowarn jogger.benchmark(; ref = ref)
#        cleanup()
#
#        # Now with fewer benchmarks
#        @test_nowarn jogger.benchmark(; ref = r)
#    end
#end

macro test_tune(s, ref)
    quote
        s = $(esc(s))
        ref = $(esc(ref))
        s_keys = collect(keys(s))
        ref_keys = collect(keys(ref))
        @test isempty(setdiff(s_keys, ref_keys))
        for ((k1, v1), (k2, v2)) in zip(leaves(s), leaves(ref))
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
    for (_, b) in leaves(suite)
        b.params.evals = rand(1:typemax(Int))
    end
    return suite
end

@testset "unit tests" begin
    jogger = @eval @jog Example
    ref_suite = () -> deepcopy(jogger.suite())

    ref_tune = ref_suite()
    tune!(ref_tune)

    @testset "Fall back to BenchmarkTools.tune!" begin
        @test_tune PkgJogger.tune!(ref_suite()) ref_tune
        @test_tune PkgJogger.tune!(ref_suite(), nothing) ref_tune
        @test_throws AssertionError PkgJogger.tune!(ref_suite(), Dict())
    end

    @testset "Reuse prior tune" begin
        rand_tune = random_tune(ref_tune)
        @test_tune PkgJogger.tune!(ref_suite(), rand_tune) rand_tune
        @test_tune PkgJogger.tune!(ref_suite(), Dict("benchmarks" => rand_tune)) rand_tune
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

        @test_tune PkgJogger.tune!(new_suite, rand_tune) expected_tune
    end

    @testset "Ignore additional tunes" begin
        # Random Tune with additional benchmarks
        rand_tune = ref_suite()
        random_tune!(rand_tune)
        expected_tune = deepcopy(rand_tune)
        rand_tune["bench_tune.jl"] = deepcopy(first(rand_tune)[2])

        @test_tune PkgJogger.tune!(ref_suite(), rand_tune) expected_tune
        @test_tune PkgJogger.tune!(ref_suite(), Dict("benchmarks" => rand_tune)) expected_tune
    end
end
