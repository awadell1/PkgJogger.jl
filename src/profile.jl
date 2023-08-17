function profile(suite, profiler::Symbol; verbose=false, ref=nothing, kwargs...)
    leaf = leaves(suite)
    @assert length(leaf) == 1 "Profiling Support is limited to one benchmark at a time"
    id, benchmark = first(leaf)
    warmup(suite; verbose)
    tune!(suite, ref)
    profile(Val(profiler), id, benchmark; verbose, kwargs...)
end

profile(p::Val, args...) = error(
    """Unknown profiler $p.
    Did you forget to load it's dependencies?
    See [`PkgJogger.profile`](@ref) for more information
    """)

function __profiling_loop(start, stop, benchmark)
    start_time = time()
    params = benchmark.params
    quote_vals = benchmark.quote_vals
    sample = 0
    while (time() - start_time) <= params.seconds && sample <= params.samples
        params.gcsample && BenchmarkTools.gcscrub()
        start()
        try
            benchmark.samplefunc(quote_vals, params)
        finally
            stop()
        end
        sample += 1
    end
    return nothing
end

"""
    profiler=:cpu

Profiles the benchmark using [`Profile.@profile`](@ref)
"""
function profile(::Val{Symbol(:cpu)}, id, b::BenchmarkTools.Benchmark; verbose)
    Profile.clear()
    __profiling_loop(Profile.start_timer, Profile.stop_timer, b)
    verbose && Profile.print()
    return nothing
end

if isdefined(Profile, :Allocs)
    @doc """
         profiler=:allocs

    Profiles memory allocations using the built-in [`Profile.Allocs.@profile`](@ref)

    Accepts `sample_rate` as a kwarg to control the rate of recordings. A rate of 1.0 will
    record everything; 0.0 will record nothing. See [`Profile.Allocs.@profile`](@ref) for more.

    !!! compat "Julia 1.8"
        The allocation profiler was added in Julia 1.8
    """
    function profile(::Val{Symbol(:allocs)}, id, b::BenchmarkTools.Benchmark; verbose, sample_rate=0.0001)
        Profile.Allocs.clear()
        start = () -> Profile.Allocs.start(; sample_rate)
        __profiling_loop(start, Profile.Allocs.stop, b)
        return nothing
    end
end
