using Test
using PkgJogger
using BenchmarkTools
using Revise

benchmark_dir = PkgJogger.benchmark_dir(PkgJogger)

function match_bg(l, r)
    l_leaves = leaves(l)
    r_leaves = leaves(r)
    leaf_name = x -> x[1]
    @test all( l_leaves .|> leaf_name == r_leaves .|> leaf_name )
end

# Note: We need to `@eval @jog PkgJogger` to delay the evaluation of `@jog`
# Otherwise it gets called on code loading and the file changes don't get captured
rlogger = Revise.debug_logger()

@testset "revise" begin
    # Create test benchmark
    src = joinpath(benchmark_dir, "bench_test.jl")
    dst = joinpath(benchmark_dir, "bench_test2.jl")
    cp(src, dst; force=true)


    @testset "Check testsets" begin
        @eval @jog PkgJogger
        s = JogPkgJogger.suite()
        @test haskey(s, "test")
        @test haskey(s, "test2")
        match_bg(s["test"], s["test2"])
    end

    @testset "Add a benchmark" begin
        @eval @jog PkgJogger
        @test ~haskey(JogPkgJogger.suite()["test2"], "apple")

        # Add the tests
        @info rlogger
        open(dst, "a") do io
            write(io, "suite[\"apple\"] = @benchmarkable sincos(rand())\n")
            flush(io)
        end
        open(dst, "r") do io
            read(io, String) |> print
        end
        Revise.revise(JogPkgJogger)
        @info rlogger

        # Check that the new test is there
        @info @eval JogPkgJogger.suite()
        @test haskey(JogPkgJogger.suite()["test2"], "apple")

        # Delete a benchmark
        cp(src, dst; force=true)
        @test ~haskey(j.suite()["test2"], "apple")


    end


    # Cleanup
    rm(dst)
end

rlogger
