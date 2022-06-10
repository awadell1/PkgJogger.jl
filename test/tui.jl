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

keydict = Dict(
    :enter => "\r",
    :left => "\x1b[D",
    :right => "\x1b[C",
    :up => "\x1b[A",
    :down => "\x1b[B",
    :ctrl_c => "\x03",
)

@testset "quit" begin
    @jog Example
    fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(JogExample; term=term)
        @test timedwait(() -> istaskdone(t), 1e-3) == :timed_out
    end
    output, err = fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(JogExample; term=term)
        write(input, "q")
        @test timedwait(() -> istaskdone(t), 1e-3) == :ok
    end
    output, err = fake_terminal() do term, input, output
        t = @async PkgJogger.TUI.tui(JogExample; term=term)
        write(input, keydict[:ctrl_c])
        @test timedwait(() -> istaskdone(t), 1e-3) == :ok
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
    fuzz_time = 5
    jogger = @eval @jog Example
    fuzz_alphabet = Set(Char.(1:128))
    delete!(fuzz_alphabet, 'q')
    delete!(fuzz_alphabet, keydict[:ctrl_c])
    output, err = fake_terminal(; timeout = fuzz_time*1.5) do term, input, output
        t = async_term(term) do
            PkgJogger.TUI.tui(jogger; term=term)
        end
        start_time = time()
        n_chars = 0
        fuzz_history = Char[]
        while (time() - start_time) < fuzz_time
            char =  rand(fuzz_alphabet)
            push!(fuzz_history, char)
            write(input, char)
            sleep(0.1)
            n_chars += 1
            istaskdone(t) && break
        end

        # Check that we're still running
        if istaskdone(t)
            @info "Fuzzed with" fuzz_history runtime=time() - start_time
            print(String(readavailable(output)))
        end
        @test istaskdone(t) == false

        # Shutdown TUI
        write(input, "q")
        try
            !istaskdone(t) && Base.throwto(t, InterruptException())
        catch e
            !(e isa InterruptException) && rethrow()
        end
        @test timedwait(() -> istaskdone(t), 1) == :ok
    end
    print(read(err, String))
    cleanup_example()
end
