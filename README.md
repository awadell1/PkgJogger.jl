# PkgJogger

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://awadell1.github.io/PkgJogger.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://awadell1.github.io/PkgJogger.jl/dev)
[![Build Status](https://github.com/awadell1/PkgJogger.jl/workflows/CI/badge.svg)](https://github.com/awadell1/PkgJogger.jl/actions)
[![Coverage Status](https://coveralls.io/repos/github/awadell1/PkgJogger.jl/badge.svg?branch=coverage)](https://coveralls.io/github/awadell1/PkgJogger.jl?branch=coverage)

[![version](https://juliahub.com/docs/PkgJogger/version.svg)](https://juliahub.com/ui/Packages/PkgJogger/AaLEJ)
[![pkgeval](https://juliahub.com/docs/PkgJogger/pkgeval.svg)](https://juliahub.com/ui/Packages/PkgJogger/AaLEJ)

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
    julia -e 'using Pkg; Pkg.add("PkgJogger"); using PkgJogger; PkgJogger.ci()'
    ```
