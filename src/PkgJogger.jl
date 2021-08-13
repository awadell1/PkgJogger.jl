module PkgJogger

using MacroTools
using BenchmarkTools
using CodecZlib
using JSON
using Pkg
using UUIDs
using Dates

export @jog

"""
Additional Packages that are required by modules created with [`@jog`](@ref)

[`PkgJogger.ci`](@ref) will add these to the benchmarking environment automatically
"""
const JOGGER_PKGS = [
    PackageSpec(name="PkgJogger", uuid="10150987-6cc1-4b76-abee-b1c1cbd91c01", path=dirname(@__DIR__)),
    PackageSpec(name="BenchmarkTools", uuid="6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"),
    PackageSpec(name="Revise", uuid="295af30f-e4ad-537b-8983-00126c2a3abe"),
]

include("dispatch.jl")
include("jogger.jl")
include("utils.jl")

end
