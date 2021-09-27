using BenchmarkTools
using Test

# Reduce Benchmarking Duration for faster testing
BenchmarkTools.DEFAULT_PARAMETERS.seconds = 0.1

const PKG_JOGGER_PATH = joinpath(@__DIR__, "..") |> abspath

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

"""
    test_subfile(parent, child)

Test that `child` is a child of `parent`
"""
function test_subfile(parent, child)
    @testset "$child in $parent" begin
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


