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
end

