using PkgJogger
using BenchmarkTools
using Example
@jog Example

include("utils.jl")

function gen_example()
    results = JogExample.benchmark()
    filename = JogExample.save_benchmarks(results)
    dict = JogExample.load_benchmarks(filename)
    uuid = get_uuid(filename)
    return results, filename, dict, uuid
end

function test_judge(f, new, old)
    @inferred f(new, old)
    judgement = f(new, old)
    @test typeof(judgement) <: BenchmarkGroup
    return judgement
end

# Run Benchmarks for testing
new = gen_example()
old = gen_example()

@testset "JogPkgName.judge($(typeof(n)), $(typeof(o)))" for (n, o) in Iterators.product(new, old)
    test_judge(JogExample.judge, n, o)
end

@testset "PkgJogger.judge($(typeof(n)), $(typeof(o)))" for (n, o) in Iterators.product(new[1:3], old[1:3])
    test_judge(PkgJogger.judge, n, o)
end

@testset "Missing Results - $(typeof(n))" for n in new
    @testset "Empty Suite" begin
        # Expect an empty judgement
        judgement = test_judge(JogExample.judge, n, BenchmarkGroup())
        isempty(judgement)
    end
    @testset "Missing Benchmark Judgement" begin
        # Get a suite of results to modify
        ref = deepcopy(first(new))
        ref_leaves = first.(leaves(ref))

        # Add a new Trial results
        name, trial = first(leaves(ref))
        name[end] = rand()
        ref[name] = deepcopy(trial)

        # Expect the extra benchmark to be skipped
        judgement = test_judge(JogExample.judge, n, ref)
        judgement_leaves = first.(leaves(judgement))
        @test Set(judgement_leaves) == Set(ref_leaves)
    end
end

cleanup_example()
