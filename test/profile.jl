using Test
using Profile
using CUDA
using NVTX

include("utils.jl")

@testset "CPU profiler" begin
    @jog Example
    Profile.clear()
    JogExample.profile("bench_timer.jl", "1ms")
    @test Profile.is_buffer_full() == false
    @test Profile.len_data() > 0
    @test occursin("profiler=:cpu", string(@doc(JogExample.profile)))
end

@testset "Allocs profiler" begin
    @jog Example
    Profile.Allocs.clear()
    @test isempty(Profile.Allocs.fetch().allocs)
    JogExample.profile("bench_timer.jl", "1ms"; profiler=:allocs, sample_rate=1)
    @test !isempty(Profile.Allocs.fetch().allocs)
    @test occursin("profiler=:allocs", string(@doc(JogExample.profile)))

    @testset "sample_rate" begin
        Profile.Allocs.clear()
        JogExample.profile("bench_timer.jl", "1ms"; profiler=:allocs, sample_rate=0)
        @test isempty(Profile.Allocs.fetch().allocs)
    end
end

@testset "CUDA profiler" begin
    @jog Example
    mktempdir() do cwd
        cd(cwd) do
            JogExample.profile("bench_timer.jl", "1ms"; profiler=:cuda)
        end
    end
    @test true # Nothing errored (Yay?)
end
