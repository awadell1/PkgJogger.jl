module PkgJoggerCUDAExt

using PkgJogger
using CUDA
using NVTX

"""
    profiler=:cuda

Profiles the benchmark using [`CUDA.@profile`](@ref).

!!! warning
    This only activates the CUDA profiler, you need to launch the profiler externally.
    See [CUDA Profiling](https://cuda.juliagpu.org/stable/development/profiling/) for documentation.

"""
function PkgJogger.profile(::Val{Symbol(:cuda)}, id, b::PkgJogger.BenchmarkTools.Benchmark; verbose)
    id_str = join(id, "/")
    CUDA.@profile external=true begin
        NVTX.@range id_str begin
            PkgJogger.BenchmarkTools.run(b)
        end
    end
end

end
