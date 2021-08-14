```@meta
CurrentModule = PkgJogger
```

# PkgJogger

PkgJogger provides a framework for running suites of
[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) benchmarks
without the boilerplate.

## Just write benchmarks

Create a `benchmark/bench_*.jl` file, define a
[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) `suite` and
go!

```julia
using BenchmarkTools
using AwesomePkg
suite = BenchmarkGroup()
suite["fast"] = @benchmarkable fast_code()
```

PkgJogger will wrap each `benchmark/bench_*.jl` in a module and bundle them into `JogAwesomePkg`

```julia
using AwesomePkg
using PkgJogger

# Creates the JogAwesomePkg module
@jog AwesomePkg

# Warmup, tune, and run all of AwesomePkg's benchmarks
JogAwesomePkg.benchmark()
```

## Benchmark, Revise, and Benchmark Again!

PkgJogger uses [Revise.jl](https://github.com/timholy/Revise.jl) to track
changes to your `benchmark/bench_*.jl` files and reload your suite as you edit.
No more waiting for benchmarks to precompile!

Tracked Changes:

- Changing your benchmarked function
- Changing benchmarking parameters (i.e. `seconds` or `samples`)
- Adding new benchmarks

Current Limitations:

- New benchmark files are not tracked
- Deleted benchmarks will stick around
- Renamed benchmarks will create a new benchmark and retain the old name

To get around the above, run `@jog PkgName` to get an updated jogger.

## Continuous Benchmarking Baked In!

Install PkgJogger, run benchmarks, and save results to a `*.json.gz` with a
one-line command.

```shell
julia -e 'using Pkg; Pkg.add("PkgJogger"); using PkgJogger; PkgJogger.ci()'
```

What gets done:

- Add the package at `pwd()` to a temporary environment
- If found, instantiate `benchmark/Project.toml` and add to the `LOAD_PATH`
- Add PkgJogger to the environment and build `JogPkgName` for your package
- Warmup, tune and run all benchmarks
- Save Benchmarking results and more to a compressed `*.json.gz` file
