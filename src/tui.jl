module TUI

using PkgJogger
using Dates
using BenchmarkTools
using REPL.Terminals
using REPL.TerminalMenus
using FoldingTrees
using Revise

struct BenchmarkLeaf{T}
    id::Vector
    name::String
    selected::Ref{Int8}
end
BenchmarkLeaf{T}(id::Vector) where {T} = BenchmarkLeaf{T}(id, string(last(id)), false)
Base.eltype(::Type{BenchmarkLeaf{T}}) where {T} = T

function BenchmarkLeaf{T}(root::Node, id) where {T}
    full_id = vcat(root.data.id, id)
    return BenchmarkLeaf{T}(full_id)
end

function benchmark_tree(g::BenchmarkTools.BenchmarkGroup; name="Benchmark Suite")
    root = Node{BenchmarkLeaf}(BenchmarkLeaf{Nothing}([], name, false))
    for (k, v) in g
        add_node!(root, k, v)
    end
    return root
end

# Add a BenchmarkGroup to the tree
function add_node!(root, k, v::BenchmarkTools.BenchmarkGroup)
    leaf = BenchmarkLeaf{BenchmarkTools.BenchmarkGroup}(root, k)
    n = Node{BenchmarkLeaf}(leaf, root)
    foreach((k, v) -> add_node!(n, k, v), keys(v), values(v))
    return n
end

function add_node!(root, k, v::T) where {T}
    leaf = BenchmarkLeaf{T}(root, k)
    return Node{BenchmarkLeaf}(leaf, root)
end

function FoldingTrees.writeoption(buf::IO, data::BenchmarkLeaf, charused::Int)
    return FoldingTrees.writeoption(buf, data.name, charused)
end

mutable struct BenchmarkSelect <: TerminalMenus.ConfiguredMenu{TerminalMenus.MultiSelectConfig}
    root::TreeMenu
    selected::Set
    benchmarks::BenchmarkTools.BenchmarkGroup
    config::TerminalMenus.MultiSelectConfig
    pagesize::Int
    pageoffset::Int
    cursor::Int
end

function BenchmarkSelect(g::BenchmarkGroup; kwargs...)
    config = TerminalMenus.MultiSelectConfig(;
        charset=:unicode, unchecked=" ", cursor='▷', kwargs...)
    root = TreeMenu(benchmark_tree(g))
    BenchmarkSelect(root, Set(), g, config, root.pagesize, root.pageoffset, 1)
end

TerminalMenus.pick(m::BenchmarkSelect, cursor::Int) = true
TerminalMenus.cancel(m::BenchmarkSelect) = empty!(m.selected)
TerminalMenus.numoptions(m::BenchmarkSelect) = TerminalMenus.numoptions(m.root) -1

function TerminalMenus.selected(m::BenchmarkSelect)
    s = BenchmarkGroup()
    for k in m.selected
        s[k] = deepcopy(m.benchmarks[k])
    end
    return s
end

function TerminalMenus.writeline(buf::IO, m::BenchmarkSelect, cursor::Int, iscursor::Bool)
    node = FoldingTrees.setcurrent!(m.root, cursor+1)
    if iscursor
        m.root.cursoridx = cursor
    end

    # Mark if folded
    m.root.currentdepth > 2 && print(buf, " "^(m.root.currentdepth-2))
    node.foldchildren ? print(buf, "+") : print(buf, " ")

    # Mark if selected
    selected = node.data.selected[]
    iscursor ? print(buf, " ▶ ") : print(buf, "   ")
    if selected == true
        print(buf, m.config.checked)
    elseif selected == false
        print(buf, m.config.unchecked)
    else
        print(buf, "◔")
    end
    print(buf, " ")
    print(buf, node.data.name)
end

function TerminalMenus.keypress(m::BenchmarkSelect, key::UInt32)
    if key == UInt32(' ') # Fold or unfold the current node
        partial_fold!(m, cursor(m)+1)
    elseif key == Int(TerminalMenus.ARROW_LEFT) # Deselect this node and children
        return deselect!(m, cursor(m)+1)
    elseif key == Int(TerminalMenus.ARROW_RIGHT) # Select this node
        return select!(m, cursor(m)+1)
    else
        return false
    end
end

cursor(m::BenchmarkSelect) = m.root.cursoridx

function partial_fold!(m::BenchmarkSelect, cursor::Int)
    node = FoldingTrees.setcurrent!(m.root, cursor)
    fold_uniform!(m, node)
    m.pagesize = m.root.pagesize
    return false
end

function fold_uniform!(m::BenchmarkSelect, n::Node)
    if n.data in m.selected
        return false
    elseif n.data isa BenchmarkLeaf{BenchmarkTools.BenchmarkGroup}
        # Recurse into subnodes
        state = map(n -> fold_uniform!(m, n), n.children)
        should_fold = all(state) || !any(state)
        should_fold && toggle!(n)
        return should_fold
    else
        # Terminal node
        return false
    end
end

select!(m::BenchmarkSelect, cursor::Int) = choose!(m, cursor, true)
deselect!(m::BenchmarkSelect, cursor::Int) = choose!(m, cursor, false)

function choose!(m::BenchmarkSelect, cursor::Int, b::Bool)
    node = FoldingTrees.setcurrent!(m.root, cursor)
    choose!(foldable(node.data), m, node, b)
    return false
end

# True if this node could contain subnodes
foldable(::BenchmarkLeaf{BenchmarkTools.BenchmarkGroup}) = true
foldable(::BenchmarkLeaf{Nothing}) = true
foldable(::Any) = false

choose!(b::Bool, args...) = choose!(Val(b), args...)
function choose!(::Val{true}, m::BenchmarkSelect, n::Node, b::Bool)
    leaves = Iterators.filter(n -> !foldable(n), n)
    fun = b ? push! : delete!
    foreach(l -> fun(m.selected, l.id), leaves)
    foreach(l -> l.selected[] = b, leaves)
    update_select!(m)
    return nothing
end

function choose!(::Val{false}, m::BenchmarkSelect, n::Node, b::Bool)
    fun = b ? push! : delete!
    fun(m.selected, n.data.id)
    n.data.selected[] = b
    update_select!(m)
    return nothing
end

function update_select!(m::BenchmarkSelect)
    node, depth = FoldingTrees.lastchild(m.root.root, 0)
    while depth >= 0
        if foldable(node.data)
            state = map(n -> n.data.selected[], node.children)
            if all(==(true), state)
                node.data.selected[] = true
            elseif all(==(false), state)
                node.data.selected[] = false
            else
                node.data.selected[] = -1
            end
        end
        if depth > 0
            node, depth = FoldingTrees.prev(node, depth)
        else
            depth = -1
        end
    end
    return nothing
end

mutable struct JoggerUI <: TerminalMenus.AbstractMenu
    jogger::Module
    menu::BenchmarkSelect
    mode::Symbol
    action::Symbol
    reference::Any
    toggles::Dict{Symbol, Bool}
    pagesize::Int
    pageoffset::Int
end

function JoggerUI(jogger)
    menu = BenchmarkSelect(jogger.suite())
    mode = :benchmark
    toggles = Dict(
        :save => true,
        :verbose => true,
        :reuse_tune => true,
    )
    JoggerUI(jogger, menu, mode, mode, :latest, toggles, menu.pagesize, menu.pageoffset)
end

TerminalMenus.numoptions(m::JoggerUI) = TerminalMenus.numoptions(m.menu)
TerminalMenus.pick(m::JoggerUI, cursor::Int) = TerminalMenus.pick(m.menu, cursor)
TerminalMenus.cancel(m::JoggerUI) = m.action = :exit
TerminalMenus.selected(m::JoggerUI) = m.action
TerminalMenus.writeline(buf::IO, m::JoggerUI, cursor::Int, iscursor::Bool) =
    TerminalMenus.writeline(buf, m.menu, cursor, iscursor)
function TerminalMenus.keypress(m::JoggerUI, key::UInt32)
    if key == UInt32('b')
        m.mode = :benchmark
        m.action = :benchmark
        return false
    elseif key == UInt32('u')
        m.mode = :judge
        m.action = :judge
        return false
    elseif key == UInt32('w')
        m.action = :review
        return true
    elseif key == UInt32('s')
        m.toggles[:save] = !m.toggles[:save]
        return false
    elseif key == UInt32('v')
        m.toggles[:verbose] = !m.toggles[:verbose]
        return false
    elseif key == UInt32('t')
        m.toggles[:reuse_tune] = !m.toggles[:reuse_tune]
        return false
    elseif key == UInt32('f')
        m.action = :select_reference
        return true
    elseif key == UInt32('r')
        m.action = :revise
        return true
    else
        TerminalMenus.keypress(m.menu, key)
    end
end

function print_toggle(io::IO, pre::String, key::String, post::String, colorize::Bool)
    print(io, pre)
    colorize ? printstyled(io, key; color=:cyan) : print(io, key)
    print(io, post)
    return nothing
end

function TerminalMenus.header(m::JoggerUI)
    io = IOBuffer()
    ioctx = IOContext(io, :color=>true)
    colorize(c::String) = sprint(() -> printstyled(c; color=:cyan))
    println(ioctx, "[q]uit. [←] to Deselect. [→] to Select. [␣] to Fold. [↵] confirm selection.")

    print(ioctx, "")
    print(ioctx, "Mode: ")
    print_toggle(ioctx, "[", "b", "]enchmark ", m.mode == :benchmark)
    print_toggle(ioctx, "j[", "u", "]dge ", m.mode == :judge)

    print(ioctx, "\nActions: ")
    print(ioctx, "[", "r", "]evise. ")
    print(ioctx, "change re[", "f", "]erence. ")
    print_toggle(ioctx, "sho[", "w", "] reference", m.mode == :review)

    print(ioctx, "\nReference: ")
    print(ioctx, m.reference)

    print(ioctx, "\nOptions: ")
    print_toggle(ioctx, "[", "v", "]erbose. ", m.toggles[:verbose])
    print_toggle(ioctx, "[", "s", "]ave. ", m.toggles[:save])
    print_toggle(ioctx, "reuse [", "t", "]une. ", m.toggles[:reuse_tune])


    return String(take!(io))
end

function tui(jogger; term=TerminalMenus.terminal)
    m = JoggerUI(jogger)
    while true
        m.action = m.mode
        action = request(term, m)
        if action == :exit
            break
        elseif action == :revise
            Revise.revise()
            m.menu = BenchmarkSelect(m.jogger.suite())
            @info "Triggered Revise"

        elseif action == :benchmark
            suite = TerminalMenus.selected(m.menu)
            if isempty(suite)
                @warn "No benchmarks selected"
            else
                !m.toggles[:verbose] && @info "Running Benchmarks for $(m.jogger.PARENT_PKG)"
                try
                    m.jogger.benchmark(suite;
                        save=m.toggles[:save],
                        verbose=m.toggles[:verbose],
                        ref=m.toggles[:reuse_tune] ? m.reference : nothing
                    )
                catch e
                    @error "An error was thrown while benchmarking" exception=(e, catch_backtrace())
                end
            end

        elseif action == :judge
            suite = TerminalMenus.selected(m.menu)
            judgement = m.jogger.judge(:latest, :oldest)
            show(judgement[suite])

        elseif action == :review
            choice = TerminalMenus.selected(m.menu)
            if isempty(choice)
                @warn "No benchmarks selected"
                continue
            end
            results = m.jogger.load_benchmarks(m.reference)["benchmarks"]
            print("\n")
            for (k, v) in leaves(results[choice])
                println(join(k, " - "))
                display(v)
                println()
            end

        elseif action == :select_reference
            trial_dir = joinpath(m.jogger.BENCHMARK_DIR, "trial")
            result_files = PkgJogger.list_benchmarks(trial_dir)
            mtimes = map(mtime, result_files)
            sdx = sortperm(mtimes; rev=true)
            identifiers = Any[]
            options = String[]

            # Add tagged identifiers
            datewidth = 25
            push!(identifiers, :latest); push!(options, "$(repeat(' ', datewidth)) latest")
            push!(identifiers, :oldest); push!(options, "$(repeat(' ', datewidth)) oldest")

            # Add options for each result file
            for (f, m) in zip(result_files[sdx], mtimes[sdx])
                uuid = PkgJogger.__get_uuid(f)
                datestr = rpad(Libc.strftime("%c", m), datewidth)
                push!(identifiers, uuid)
                push!(options, "$datestr $uuid")
            end

            ref_picker = TerminalMenus.RadioMenu(options; charset=:unicode)
            println("Select a reference for tuning / judging.")
            println("[q]uit to cancel. [↵] to confirm.")
            println("   $(rpad("Date", datewidth)) Identifier")
            choice = request(term, ref_picker)
            if choice != -1
                m.reference = identifiers[choice]
            end
        else
            @warn "Unknown action: $action, Please report this: https://github.com/awadell1/PkgJogger.jl/issues"
            break
        end
        println("") # Add some space with the last menu
    end
end

end
