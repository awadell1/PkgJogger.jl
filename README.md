# PkgJogger

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://awadell1.github.io/PkgJogger.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://awadell1.github.io/PkgJogger.jl/dev)
[![Build Status](https://github.com/awadell1/PkgJogger.jl/workflows/CI/badge.svg)](https://github.com/awadell1/PkgJogger.jl/actions)

PkgJogger is a benchmarking framework for Julia built on
[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) with the
following features:

- Just write benchmarks files:`benchmark/bench_*.jl`

    PkgJogger will wrap each benchmark file into a separate module, and return a
    top-level module with helper methods for running the suite

    Individual benchmark files only need to define a `suite::BenchmarkGroup`

- Revise, benchmark, and revise again

    PkgJogger uses [Revise.jl](https://github.com/timholy/Revise.jl) to track
    changes to benchmarking files and updates the suite as you edit. No more
    waiting for benchmarks to precompile!

- Continuous Benchmarking Baked In!

    Setup and isolated environment, run benchmarks and save results with a
    one-liner:

    ```shell
    julia -e 'using Pkg; Pkg.add("PkgJogger"); PkgJogger.ci()'
    ```
