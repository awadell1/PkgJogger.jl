module TUI

using PkgJogger
using BenchmarkTools
using REPL.TerminalMenus
using FoldingTrees

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
TerminalMenus.numoptions(m::BenchmarkSelect) = TerminalMenus.numoptions(m.root)

function TerminalMenus.selected(m::BenchmarkSelect)
    s = BenchmarkGroup()
    for k in m.selected
        s[k] = deepcopy(m.benchmarks[k])
    end
    return s
end

function TerminalMenus.header(m::BenchmarkSelect)
    return """
    Choose benchmarks from the suite. [q]uit. [↵] to confirm. [←] Deselect [→] Select
    """
end

function TerminalMenus.writeline(buf::IO, m::BenchmarkSelect, cursor::Int, iscursor::Bool)
    node = FoldingTrees.setcurrent!(m.root, cursor)
    if iscursor
        m.root.cursoridx = cursor
    end

    # Mark if folded
    node.foldchildren ? print(buf, "+") : print(buf, " ")

    # Mark if selected
    selected = node.data.selected[]
    if selected == true
        print(buf, m.config.checked)
    elseif selected == false
        print(buf, m.config.unchecked)
    else
        print(buf, "◔")
    end
    print(buf, " "^m.root.currentdepth)
    FoldingTrees.writeoption(buf, node.data, m.root.currentdepth+4)
end

function TerminalMenus.keypress(m::BenchmarkSelect, key::UInt32)
    if key == UInt32(' ') # Fold or unfold the current node
        partial_fold!(m, cursor(m))
    elseif key == Int(TerminalMenus.ARROW_LEFT) # Deselect this node and children
        return deselect!(m, cursor(m))
    elseif key == Int(TerminalMenus.ARROW_RIGHT) # Select this node
        return select!(m, cursor(m))
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

function tui(x; kwargs...)
    menu = BenchmarkSelect(PkgJogger._get_benchmarks(x); kwargs...)
    choice = request(menu)
    return choice
end

end
