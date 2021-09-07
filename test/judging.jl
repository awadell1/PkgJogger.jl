using PkgJogger
using BenchmarkTools

include("utils.jl")

# Add Example
using Pkg
Pkg.develop(path="Example.jl/")
using Example
@jog Example

# Run Benchmarks for testing
r1 = JogExample.benchmark() |> JogExample.save_benchmarks
r2 = JogExample.benchmark() |> JogExample.save_benchmarks

# Get UUIDs
r1_uuid = get_uuid(r1)
r2_uuid = get_uuid(r2)

@test typeof(PkgJogger.judge(r1, r2)) <: BenchmarkGroup
@testset "Test loading" for new=[r1, r1_uuid], old=[r2, r2_uuid]
    @test typeof(JogExample.judge(new, old)) <: BenchmarkGroup
end
