using BenchmarkTools
using Test

const PKG_JOGGER_PATH = joinpath(@__DIR__, "..") |> abspath

function test_loaded_results(r::Dict)
    @test haskey(r, "julia")
    @test haskey(r, "system")
    @test haskey(r, "datetime")
    @test haskey(r, "benchmarks")
    @test r["benchmarks"] isa BenchmarkTools.BenchmarkGroup
end

"""
    create_temp_version()

Copy all tracked files to a temporary directory that can be developed
Used to replicate Pkg.add against the current version
"""
function create_temp_version()
    # Check if under version control
    if isdir(joinpath(PKG_JOGGER_PATH, ".git"))
        # Only Copy git tracked files
        files = readlines(Cmd(`git ls-files`, dir=PKG_JOGGER_PATH))
    else
        # Copy all files
        files = glob("**/*")
    end

    # Copy Package Files to temporary directory
    dir = mktempdir(; prefix="jl_pkgjogger_", cleanup=true)
    for file in readlines(Cmd(`git ls-files`, dir=PKG_JOGGER_PATH))
        src = joinpath(PKG_JOGGER_PATH, file)
        dst = joinpath(dir, file)
        mkpath(dirname(dst))
        cp(src, dst; force=true)
    end
    return dir
end


