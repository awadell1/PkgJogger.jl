module PkgJogger

using BenchmarkTools
using CodecZlib
using JSON
using BSON
using Pkg
using UUIDs
using Dates
using LibGit2
using Statistics
using Test
using Profile

export @jog, @test_benchmarks

import Base: PkgId
"""
Packages that are required by modules created with [`@jog`](@ref)

Generated modules will access these via `Base.loaded_modules`
"""
const JOGGER_PKGS = [
    Base.identify_package(@__MODULE__, string(@__MODULE__)),
    PkgId(UUID("6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"), "BenchmarkTools"),
    PkgId(UUID("cf7118a7-6976-5b1a-9a39-7adc72f591a4"), "UUIDs"),
]

const PKG_JOGGER_VER = VersionNumber(
    Base.parsed_toml(joinpath(@__DIR__, "..", "Project.toml"))["version"]
)

include("utils.jl")
include("profile.jl")
include("jogger.jl")
include("ci.jl")

end
