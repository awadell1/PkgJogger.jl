@testsetup module BenchmarkTests

using Test
using BenchmarkTools

export test_loaded_results, test_subfile, get_uuid, test_benchmark, results_match

# Reduce Benchmarking Duration for faster testing
BenchmarkTools.DEFAULT_PARAMETERS.seconds = 0.1

function test_loaded_results(r::Dict)
    @test haskey(r, "julia")
    @test haskey(r, "system")
    @test haskey(r, "datetime")
    @test haskey(r, "benchmarks")
    @test r["benchmarks"] isa BenchmarkTools.BenchmarkGroup
    @testset "git" begin
        @test haskey(r, "git")
        if r["git"] !== nothing
            @test haskey(r["git"], "commit")
            @test haskey(r["git"], "is_dirty")
            @test haskey(r["git"], "datetime")
        end
    end
end

function results_match(x::Dict, y::Dict)
    x["benchmarks"] == y["benchmarks"] || return false
    x["julia"] == y["julia"] || return false
    x["pkgjogger"] == y["pkgjogger"] || return false
    x["datetime"] == y["datetime"] || return false
    return true
end

"""
    test_subfile(parent, child)

Test that `child` is a child of `parent`
"""
function test_subfile(parent, child)
    @testset "subfile-check" begin
        @test isfile(child)
        @test isdir(parent)

        # Get full path split into parts
        parent_path = splitpath(abspath(parent))
        child_path = splitpath(abspath(child))

        # Check that parent is a root of child
        n = length(parent_path)
        @assert n < length(child_path)
        @test all( parent_path .== child_path[1:n])
    end
end

"""
    get_uuid(filename)

Extract benchmark UUID from filename
"""
function get_uuid(filename)
    splitpath(filename)[end] |> x -> split(x, ".")[1]
end

"""
    test_benchmark(target::BenchmarkGroup, ref)

Checks that target and ref are from equivalent benchmarking suite
"""
function test_benchmark(target, ref::BenchmarkGroup)
    @test typeof(target) <: BenchmarkGroup
    @test isempty(setdiff(keys(target), keys(ref)))
    map(test_benchmark, target, ref)
end
test_benchmark(target, ref) = @test typeof(target) <: typeof(ref)
function test_benchmark(target, ref::BenchmarkTools.Trial)
    @test typeof(target) <: BenchmarkTools.Trial
    @test params(target) == params(ref)
end

end

@testsetup module ExamplePkg
using PkgJogger
using TOML
using UUIDs
using Random
using Pkg
export create_example, add_benchmark

function copy_fake(src, dst, fake)
    lines = open(readlines, src, "r")
    lines = map(l -> replace(l, r"Example" => fake), lines)
    open(dst, "w") do io
        println.(io, lines)
    end
    return dst
end

function create_jogger()
    Example, cleanup = create_example()
    jogger = create_jogger(Example)
    return jogger, cleanup
end

function create_jogger(pkg::Symbol)
    eval(Expr(:macrocall, Symbol("@jog"), LineNumberNode(@__LINE__, @__FILE__), pkg))
    return getproperty(@__MODULE__, Symbol(:Jog, pkg))
end

# Create Dummy Example Package for Testing
function create_example()
    # Copy Example package to temp directory
    dir = mktempdir()
    fakename = "Example" * randstring(8)
    chmod(dir, 0o700)
    src_dir =  joinpath(PkgJogger.pkgdir(PkgJogger), "test", "Example.jl")
    for (root, _, files) in walkdir(src_dir)
        dst_root = abspath(joinpath(dir, relpath(root, src_dir)))
        mkpath(dst_root; mode=0o700)
        for file in files
            dst = joinpath(dst_root, file)
            copy_fake(joinpath(root, file), dst, fakename)
            chmod(dst, 0o600)
        end
    end

    # Setup Finalizer to cleanup
    function cleanup()
        rm(dir; force=true, recursive=true)
        filter!(!=(dir), LOAD_PATH)
    end

    # Fake a new module
    project_file = joinpath(dir, "Project.toml")
    project = TOML.parsefile(project_file)
    project["name"] = fakename
    project["uuid"] = string(UUIDs.uuid4())
    open(io -> TOML.print(io, project), project_file, "w")
    mv(joinpath(dir, "src", "Example.jl"), joinpath(dir, "src", fakename * ".jl"))

    # Create dummy module
    name = Symbol(fakename)
    try
        @info "Creating $fakename for testing in $dir"
        project = Base.active_project()
        Pkg.activate(dir)
        Pkg.instantiate(; verbose=false)
        push!(LOAD_PATH, dir)
        @eval import $name
        Pkg.activate(project)
    catch e
        cleanup()
        rethrow(e)
    end

    return name, cleanup
end



end
