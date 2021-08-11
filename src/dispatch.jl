# This file contains functions that the generated modules will dispatch to

# List of Module => function that `JogPkgName` will dispatch to
const DISPATCH_METHODS = [
    :BenchmarkTools => :run,
    :BenchmarkTools => :warmup,
    :PkgJogger => :benchmark
]

"""
    benchmark(s::BenchmarkGroup)

Warmup, tune and run a benchmark suite
"""
function benchmark(s::BenchmarkTools.BenchmarkGroup; kwargs...)
    warmup(s)
    tune!(s)
    BenchmarkTools.run(s)
end
