# PkgJogger

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://awadell1.github.io/PkgJogger.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://awadell1.github.io/PkgJogger.jl/dev)
[![Build Status](https://github.com/awadell1/PkgJogger.jl/workflows/CI/badge.svg)](https://github.com/awadell1/PkgJogger.jl/actions)
[![Coverage Status](https://coveralls.io/repos/github/awadell1/PkgJogger.jl/badge.svg?branch=main)](https://coveralls.io/github/awadell1/PkgJogger.jl?branch=main)

[![version](https://juliahub.com/docs/PkgJogger/version.svg)](https://juliahub.com/ui/Packages/PkgJogger/AaLEJ)
[![pkgeval](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/P/PkgJogger.svg)](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html)
[![Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Fmonthly_downloads%2FPkgJogger&query=total_requests&suffix=%2Fmonth&label=Downloads)](https://juliapkgstats.com/pkg/PkgJogger)

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

> Note: Revise must be loaded first in order to track changes to your benchmark files.

## Continuous Benchmarking Baked In!

Install PkgJogger, run benchmarks, and save results to a `*.bson.gz` with a
one-line command.

```shell
julia -e 'using Pkg; Pkg.add("PkgJogger"); using PkgJogger; PkgJogger.ci()'
```

What gets done:

- Constructs a temporary
  [benchmarking environment](https://awadell1.github.io/PkgJogger.jl/stable/ci/#Isolated-Benchmarking-Environment)
  from `Project.toml` and `benchmark/Project.toml`.
- Creates a [jogger](https://awadell1.github.io/PkgJogger.jl/stable/jogger/)
  to run the package's benchmarks.
- Warmup, tune and run all benchmarks.
- Save Benchmarking results and more to a compressed `*.bson.gz` file.

Or for a more lightweight option, use
[`@test_bechmarks`](https://awadell1.github.io/PkgJogger.jl/stable/ci/#Testing-Benchmarks)
to run each benchmark once (No Warmup, tuning, etc.), as a smoke test
against benchmarking regressions.
