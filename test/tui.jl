using Test
using BenchmarkTools
using PkgJogger
using Example
using Logging

import REPL

include("utils.jl")

# fake_terminals was taken from Cthutu's FakeTerminals
#   https://github.com/JuliaDebug/Cthulhu.jl/blob/master/test/FakeTerminals.jl
function fake_terminal(f; timeout=60, options::REPL.Options=REPL.Options(confirm_exit=false))
    # Use pipes so we can easily do blocking reads
    # In the future if we want we can add a test that the right object
    # gets displayed by intercepting the display
    input = Pipe()
    output = Pipe()
    err = Pipe()
    Base.link_pipe!(input, reader_supports_async=true, writer_supports_async=true)
    Base.link_pipe!(output, reader_supports_async=true, writer_supports_async=true)
    Base.link_pipe!(err, reader_supports_async=true, writer_supports_async=true)

    term_env = get(ENV, "TERM", @static Sys.iswindows() ? "" : "dumb")
    term = REPL.Terminals.TTYTerminal(term_env, input.out, IOContext(output.in, :color=>true), err.in)

    # Launch the Fake Terminal
    f(term, input, output)

    # Close input/output/err pipes
    t = @async begin
        close(input.in)
        close(output.in)
        close(err.in)
    end
    wait(t)

    return output, err
end

function async_term(f, term::REPL.Terminals.TTYTerminal)
    @async begin
        redirect_stdout(term.out_stream) do
            redirect_stderr(term.err_stream) do
                f()
            end
        end
    end
end

"""
    Base.kill(t::Task)

Kill a task by throwing an InterruptException to the task.
If the task is not running, do nothing
"""
function Base.kill(t::Task)
    try
        !istaskdone(t) && Base.throwto(t, InterruptException())
    catch e
        !(e isa InterruptException) && rethrow()
    end
end

"""
    enforce_exit(t::Task, timeout=1e-3)

Return true if the task has exited or exits within the given `timeout`
After `timeout` seconds, the task will be killed `kill(t)`
"""
function enforce_exit(t::Task, timeout=1e-3)
    exit_code = timedwait(() -> istaskdone(t),timeout)
    kill(t)
    return exit_code == :ok
end

# Map keycodes to their unicode representation
keydict = Dict(
    :enter => "\r",
    :left => "\x1b[D",
    :right => "\x1b[C",
    :up => "\x1b[A",
    :down => "\x1b[B",
    :ctrl_c => "\x03",
    :ctrl_d => "\x04",
)

@testset "quit" begin
    jogger = @eval @jog Example
    fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(jogger; term=term)
        @test enforce_exit(t) == false
    end
    output, err = fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(jogger; term=term)
        write(input, "q")
        exit_code = timedwait(() -> istaskdone(t), 1e-3)
        @test enforce_exit(t)
    end
    output, err = fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(jogger; term=term)
        interrupt_thrown = false
        try
            write(input, keydict[:ctrl_c])
            sleep(1e-3)
        catch e
            @test e isa InterruptException
            interrupt_thrown = true
        end
        @test enforce_exit(t)
        @test interrupt_thrown
    end
end

@testset "catch errors" begin
    trigger_error = """
    using Example
    using BenchmarkTools
    const suite = BenchmarkGroup()
    suite["error"] = @benchmarkable error()
    """
    suite, cleanup = add_benchmark(Example, "bench_0000_$(rand(UInt16)).jl", trigger_error)
    jogger = @eval @jog Example

    output, err = fake_terminal(; timeout = 10) do term, input, output
        t = async_term(term) do
            PkgJogger.TUI.tui(jogger; term=term)
        end
        write(input,
            "b", # Benchmark Mode
            keydict[:right], # Select All
            keydict[:enter], # Run
        )
        yield()
        write(input, "q")
        @test timedwait(() -> istaskdone(t), 1) == :ok
        @test istaskfailed(t) == false
    end
    @test occursin("An error was thrown while benchmarking", read(err, String))
    cleanup()
    cleanup_example()
end

@testset "fuzz keyboard" begin
    fuzz_duration = 5
    cleanup_example()
    jogger = @eval @jog Example

    # Construct fuzzing alphabet
    # - Remove characters that are expected to trigger exits
    fuzz_alphabet = Set((string∘Char).(32:128))
    union!(fuzz_alphabet, values(keydict))
    delete!(fuzz_alphabet, "q")
    delete!(fuzz_alphabet, keydict[:ctrl_c])
    delete!(fuzz_alphabet, keydict[:ctrl_d])

    # Simulate terminal with a stream of random keypresses
    @info "Starting Fuzzing the TUI for $fuzz_duration seconds"
    output, err = fake_terminal(; timeout = fuzz_duration*1.5) do term, input, output
        t = @async PkgJogger.TUI.tui(jogger; term=term)
        start_time = time()
        n_chars = 0
        @test istaskdone(t) == false

        # Write random keypresses to the input stream and record the last 64 keypresses
        # in a channel.
        fuzz_history = Channel{String}(64)
        function fuzz_terminal(c::Channel{String})
            start_time = time()
            while time() - start_time < fuzz_duration
                char = rand(fuzz_alphabet)
                length(c.data) >= c.sz_max && take!(c)
                put!(c, char)
                write(input, char)
                yield()
                sleep(1e-2)
            end
        end
        fuzzer = @async fuzz_terminal(fuzz_history)
        wait(fuzzer)

        # Check that we're still running
        if istaskdone(t)
            fuzzed = []
            while isready(fuzz_history)
               push!(fuzzed, take!(fuzz_history))
            end
            @info "Fuzzed with" fuzzed runtime=time() - start_time
            println("stdout:")
            print(String(readavailable(output)))
        end
        @test istaskdone(t) == false

        # Shutdown TUI
        write(input, "q")
        yield()
        @test enforce_exit(t)
    end
    @info "Finished Fuzzing the TUI"
    cleanup_example()
end
