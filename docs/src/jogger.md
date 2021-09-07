# Generated Jogger Modules

At it's core `PkgJogger` uses meta-programming to generate a Jogger module for
running a package's benchmarks. For example, calling `@jog` on `PkgJogger` gives
a jogger named `JogPkgJogger` for running the benchmark suite of `PkgJogger`.

```jldoctest jogger
julia> using PkgJogger

julia> @jog PkgJogger
JogPkgJogger

```

Similarly, `@jog AwesomePkg` would create a module named `JogAwesomePkg`.

```@docs
PkgJogger.@jog
```

## Jogger Reference

Jogger modules provide helper methods for working with their package's
benchmarking suite. For reference, this sections documents the methods for `@jog
Example`.

```@docs
JogExample.suite
JogExample.benchmark
JogExample.warmup
JogExample.run
JogExample.save_benchmarks
JogExample.load_benchmarks
JogExample.BENCHMARK_DIR
```
