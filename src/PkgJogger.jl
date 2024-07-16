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
using Compat: @compat

export @jog, @test_benchmarks
@compat public judge, ci, load_benchmarks, save_benchmarks, locate_benchmarks, tune!, getsuite, profile

"""
Packages that are required by modules created with [`@jog`](@ref)

Generated modules will access these via `Base.loaded_modules`
"""
const JOGGER_PKGS = [
    Base.identify_package(@__MODULE__, string(@__MODULE__)),
    Base.PkgId(UUID("6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"), "BenchmarkTools"),
    Base.PkgId(UUID("cf7118a7-6976-5b1a-9a39-7adc72f591a4"), "UUIDs"),
    Base.PkgId(UUID("34da2185-b29b-5c13-b0c7-acf172513d20"), "Compat"),
]

const PKG_JOGGER_VER = VersionNumber(
    Base.parsed_toml(joinpath(@__DIR__, "..", "Project.toml"))["version"]
)

include("utils.jl")
include("profile.jl")
include("jogger.jl")
include("ci.jl")

end
