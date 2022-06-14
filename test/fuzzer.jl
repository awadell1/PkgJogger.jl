module Fuzzer
using REPL
using Mocking
Mocking.activate()

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

# Construct fuzzing alphabet
# - Remove characters that are expected to trigger exits
fuzz_alphabet = Set((string∘Char).(32:128))
union!(fuzz_alphabet, values(keydict))
delete!(fuzz_alphabet, "q")
delete!(fuzz_alphabet, keydict[:ctrl_c])
delete!(fuzz_alphabet, keydict[:ctrl_d])

# Overload REPL.TerminalMenus.readkey to return a random keycodes
fuzz_seq = Channel{Char}(32)
function fuzz_readbyte()
    if !isready(fuzz_seq)
        chars = Vector{Char}(rand(fuzz_alphabet))
        foreach(Base.Fix1(put!, fuzz_seq), chars)
    end
    c = take!(fuzz_seq)
    @debug "Fuzzing" c
    return c
end

function REPL.TerminalMenus.readbyte(stream::IO)
    return @mock read(stream, Char)
end
patch_readbyte = @patch read(stream::IO, ::Type{Char}) = fuzz_readbyte()

function ui_fuzzer(f, duration)
    task = @async begin
        redirect_stdout(Base.DevNull) do
            apply(patch_readbyte) do
               f()
            end
        end
    end
    return task
end

end
