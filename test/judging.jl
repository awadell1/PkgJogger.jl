using PkgJogger
using BenchmarkTools

include("utils.jl")

# Add Example
using Pkg
Pkg.develop(path="Example.jl/")
using Example
@jog Example

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
end

# Run Benchmarks for testing
new = gen_example()
old = gen_example()

@testset "Test PkgJogger.judge" for (n, o) in Iterators.product(new[1:3], old[1:3])
    test_judge(PkgJogger.judge, n, o)
end
@testset "Test JogPkgName.judge" for (n, o) in Iterators.product(new, old)
    test_judge(JogExample.judge, n, o)
end
