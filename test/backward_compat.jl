using Test
using JSON
using PkgJogger
using Example
using CodecZlib
using Dates

include("utils.jl")

# Get Benchmarking results
@jog Example
b = JogExample.benchmark()

# Save using JSON
function save_benchmarks(filename, results::BenchmarkTools.BenchmarkGroup)
    # Collect system information to save
    mkpath(dirname(filename))
    out = Dict(
        "julia" => PkgJogger.julia_info(),
        "system" => PkgJogger.system_info(),
        "datetime" => string(Dates.now()),
        "benchmarks" => results,
        "git" => PkgJogger.git_info(filename),
    )

    # Write benchmark to disk
    open(GzipCompressorStream, filename, "w") do io
        JSON.print(io, out)
    end
end

@testset "Compat *.json.gz" begin
    f = tempname(; cleanup=false) * ".json.gz"
    finalizer(rm, f)
    save_benchmarks(f, b)

    # Check that the deprecated warming is logged
    local b2
    @test_logs (:warn, r"Legacy `\*\.json\.gz` format is deprecated.*") begin
        b2 = JogExample.load_benchmarks(f)
    end

    # Check that benchmarks are still there
    @test b2 isa Dict
    @test haskey(b2, "benchmarks")
    @test b2["benchmarks"] isa BenchmarkTools.BenchmarkGroup
end

