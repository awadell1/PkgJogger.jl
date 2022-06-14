using Test
using BenchmarkTools
using PkgJogger
using Example
using Logging
using Mocking
Mocking.activate()

import REPL

include("utils.jl")

include("fuzzer.jl")
using .Fuzzer

@testset "fuzz tui" begin
    jogger = @eval @jog Example
    yield()
    start_time = time()
    t = @async begin
        Fuzzer.fuzz_ui(jogger.tui)
    end

    # Check that fuzzing didn't timeout (should run for ~1 second)
    # and that it ran for at least 1 second
    @test timedwait(() -> istaskdone(t), 3.0; pollint=0.2) == :ok
    @test time() - start_time >= 1
    cleanup_example()
end
