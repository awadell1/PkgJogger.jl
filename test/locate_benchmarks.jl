using Test
using BenchmarkTools
using PkgJogger
using Example

include("utils.jl")

function check_suite(jogger; add=nothing)
    # Default Suite
    reference = [
        ["bench_timer.jl", "1ms"],
        ["bench_timer.jl", "2ms"],
    ] |> Set

    if add !== nothing
        reference = union(reference, add)
    end

    # Get suite of jogger
    suite = Set(jogger.suite() |> leaves |> x -> map(first, x))
    @test suite == reference
end

@testset "default suite" begin
    jogger = @eval @jog Example
    check_suite(jogger)
end

@testset "Add benchmarks" begin
    suite, cleanup = add_benchmark(Example, "bench_foo_$(rand(UInt16)).jl")
    jogger = @eval @jog Example
    check_suite(jogger; add=suite)

    # Add a non-benchmarking file (Should not be added)
    cleanup2 = add_benchmark(Example, "foo_$(rand(UInt16)).jl")[2]
    check_suite(jogger; add=suite)

    # Add another file (should not be added)
    suite3, cleanup3 = add_benchmark(Example, "bench_foo_$(rand(UInt16)).jl")
    check_suite(jogger; add=suite)

    # Regenerate jogger to get new suite -> Should now just be suite3 + suite
    jogger = @eval @jog Example
    check_suite(jogger; add=union(suite, suite3))

    cleanup()
    cleanup2()
    cleanup3()
end

@testset "Benchmarks in subfolders" begin
    # Add a subfolder -> Don't track
    jogger = @eval @jog Example
    tempdir = mktempdir(jogger.BENCHMARK_DIR; cleanup=false)
    check_suite(jogger)
    rm(tempdir)

    # Add an empty bench_ subfolder -> Ignore
    tempdir = mktempdir(jogger.BENCHMARK_DIR; prefix="bench_", cleanup=false)
    check_suite(jogger)
    rm(tempdir)

    # Add a benchmark to a subfolder -> track
    path = joinpath("bench_subdir_$(rand(UInt16))", "bench_foo_$(rand(UInt16)).jl")
    suite, cleanup = add_benchmark(Example, path)
    check_suite(@eval @jog Example; add=suite)
    cleanup()

    # Two Levels Deep
    dir = "bench_subdir_$(rand(UInt16))"
    suite, cleanup = add_benchmark(Example, joinpath(dir, "bench_foo_$(rand(UInt16)).jl"))
    union!(suite, add_benchmark(Example, joinpath(dir, "bench_l2", "bench_foo_$(rand(UInt16)).jl"))[1])
    add_benchmark(Example, joinpath(dir, "skip_me.jl"))
    check_suite(@eval @jog Example; add=suite)
    cleanup()
end
