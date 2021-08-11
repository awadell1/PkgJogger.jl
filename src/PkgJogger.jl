module PkgJogger

using MacroTools
using BenchmarkTools

export @jog

include("dispatch.jl")
include("jogger.jl")

end
