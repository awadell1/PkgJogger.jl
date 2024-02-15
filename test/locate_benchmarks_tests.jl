@testsetup module SuiteCheck
using Test
using BenchmarkTools
using PkgJogger

export add_benchmark, check_suite

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
    suite = Set(jogger.suite() |> BenchmarkTools.leaves |> x -> map(first, x))
    @test suite == reference
end

function add_benchmark(jogger, path)
    filename = joinpath(jogger.BENCHMARK_DIR, path)
    dir = dirname(filename)
    mkpath(dir)

    open(filename, "w") do io
        """
        using BenchmarkTools

        suite = BenchmarkGroup()
        suite["foo"] = @benchmarkable sin(rand())
        """ |> s -> write(io, s)
    end

    return Set{Vector{String}}([[splitpath(path)..., "foo"]])
end

end

@testitem "default suite" setup=[ExamplePkg, SuiteCheck] begin
    jogger, cleanup = ExamplePkg.create_jogger()
    check_suite(jogger)
    cleanup()
end

@testitem "Add benchmarks" setup=[ExamplePkg, SuiteCheck] begin
    fakepkg, cleanup = ExamplePkg.create_example()
    jogger = ExamplePkg.create_jogger(fakepkg)
    suite = add_benchmark(jogger, "bench_foo_$(rand(UInt16)).jl")
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger; add=suite)

    # Add a non-benchmarking file (Should not be added)
    add_benchmark(jogger, "foo_$(rand(UInt16)).jl")
    check_suite(jogger; add=suite)

    # Add another file (should not be added)
    suite3 = add_benchmark(jogger, "bench_foo_$(rand(UInt16)).jl")
    check_suite(jogger; add=suite)

    # Regenerate jogger to get new suite -> Should now just be suite3 + suite
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger; add=union(suite, suite3))

    cleanup()
end

@testitem "Benchmarks in subfolders" setup=[ExamplePkg, SuiteCheck] begin
    # Add a subfolder -> Don't track
    fakepkg, cleanup = ExamplePkg.create_example()
    jogger = ExamplePkg.create_jogger(fakepkg)
    tempdir = mktempdir(jogger.BENCHMARK_DIR; cleanup=false)
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger)
    rm(tempdir)

    # Add an empty bench_ subfolder -> Ignore
    tempdir = mktempdir(jogger.BENCHMARK_DIR; prefix="bench_", cleanup=false)
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger)

    # Add a benchmark to a subfolder -> track
    path = joinpath("bench_subdir_$(rand(UInt16))", "bench_foo_$(rand(UInt16)).jl")
    suite = add_benchmark(jogger, path)
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger; add=suite)

    # Two Levels Deep
    dir = "bench_subdir_$(rand(UInt16))"
    suite = union(
        suite,
        add_benchmark(jogger, joinpath(dir, "bench_foo_$(rand(UInt16)).jl")),
        add_benchmark(jogger, joinpath(dir, "bench_l2", "bench_foo_$(rand(UInt16)).jl")),
    )
    add_benchmark(jogger, joinpath(dir, "skip_me.jl"))
    jogger = ExamplePkg.create_jogger(fakepkg)
    check_suite(jogger; add=suite)
    cleanup()
end
