module Fuzzer
using REPL
using Pretend
Pretend.activate()

using REPL.TerminalMenus: numoptions, move_down!, move_up!, page_down!, page_up!, cancel, printmenu, keypress, selected, pick,
    ARROW_UP, ARROW_DOWN, PAGE_UP, PAGE_DOWN, HOME_KEY, END_KEY

import REPL.TerminalMenus.request
@mockable REPL.TerminalMenus.request(m::REPL.TerminalMenus.AbstractMenu)

struct FuzzingTimedOut <: Exception end

function fuzz_ui(f; fuzz_kwargs...)
    start_time=time()
    function timed_request(m::REPL.TerminalMenus.AbstractMenu)
        fuzz_request(m; start_time, fuzz_kwargs...)
    end
    patch = REPL.TerminalMenus.request => timed_request
    try
        Pretend.apply(f, patch)
        return false
    catch e
        if e isa FuzzingTimedOut
            return true
        else
            throw()
        end
    end
end

function fuzz_ui_seq(f, seq; fuzz_kwargs...)
    start_time=time()
    function timed_request(m::REPL.TerminalMenus.AbstractMenu)
        fuzz_request(m; start_time, tome=seq, fuzz_kwargs...)
    end
    patch = REPL.TerminalMenus.request => timed_request
    try
        Pretend.apply(f, patch)
        return false
    catch e
        if e isa FuzzingTimedOut
            return true
        else
            throw()
        end
    end
end



function base_tome()
    tome = Set((UInt32).(1:128)) # Base ASCII Characters
    push!(tome, UInt32(REPL.TerminalMenus.ARROW_UP))
    push!(tome, UInt32(REPL.TerminalMenus.ARROW_DOWN))
    push!(tome, UInt32(13)) # Enter
    delete!(tome, UInt32('q')) # Remove q - Triggers exit
    delete!(tome, 3)   # Remove ctrl-c - Triggers exit

    Iterators.map(_ -> rand(tome), Iterators.countfrom(1))
    return tome
end

default_tome() = Iterators.map(_ -> rand(base_tome()), Iterators.countfrom(1))

function fuzz_request(m::REPL.TerminalMenus.AbstractMenu, duration::Float64=1.0;
    fuzz_tome=default_tome(),
    start_time::Float64=time(),
    cursor=1,
    raw_mode_enabled=false,
)
    # Check if done start
    if time() - start_time > duration
        throw(FuzzingTimedOut())
    end

    # Setup
    out_stream = devnull
    cursor = cursor isa Int ? Ref(cursor) : cursor
    state = printmenu(out_stream, m, cursor[], init=true)

    # hide the cursor
    raw_mode_enabled && print(out_stream, "\x1b[?25l")

    for c in fuzz_tome
        if time() - start_time > duration
            throw(FuzzingTimedOut())
        end
        lastoption = numoptions(m)
        if c == Int(ARROW_UP)
            cursor[] = move_up!(m, cursor[], lastoption)
        elseif c == Int(ARROW_DOWN)
            cursor[] = move_down!(m, cursor[], lastoption)
        elseif c == Int(PAGE_UP)
            cursor[] = page_up!(m, cursor[], lastoption)
        elseif c == Int(PAGE_DOWN)
            cursor[] = page_down!(m, cursor[], lastoption)
        elseif c == Int(HOME_KEY)
            cursor[] = 1
            m.pageoffset = 0
        elseif c == Int(END_KEY)
            cursor[] = lastoption
            m.pageoffset = lastoption - m.pagesize
        elseif c == 13 # <enter>
            # will break if pick returns true
            pick(m, cursor[]) && break
        elseif c == UInt32('q')
            cancel(m)
            break
        elseif c == 3 # ctrl-c
            cancel(m)
            throw(InterruptException())
        else
            # will break if keypress returns true
            keypress(m, c) && break
        end
        # print the menu
        state = printmenu(out_stream, m, cursor[], oldstate=state)
        yield()
    end

    return selected(m)
end

end
