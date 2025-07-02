module PkgJogger

using BenchmarkTools: BenchmarkTools, BenchmarkGroup
using CodecZlib: GzipCompressorStream, GzipDecompressorStream
using JSON: JSON
using BSON: BSON
using Pkg: Pkg
using UUIDs: UUIDs, UUID
using Dates: Dates
using LibGit2: LibGit2
using Statistics: Statistics
using Test: @testset, @test
using Profile: Profile
using Compat: @compat
using TOML: TOML

export @jog, @test_benchmarks
@compat public ci, load_benchmarks, save_benchmarks

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
    TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))["version"]
)

include("utils.jl")
include("profile.jl")
include("jogger.jl")
include("ci.jl")

end
