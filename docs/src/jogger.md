# Generated Jogger Modules

At it's core `PkgJogger` uses meta-programming to generate a Jogger module for
running a package's benchmarks. For example, calling `@jog` on `Example` gives
a jogger named `JogExample` for running the benchmark suite of `Example`.

```jldoctest
julia> using PkgJogger, Example

julia> @jog Example
JogExample

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
JogExample.judge
JogExample.BENCHMARK_DIR
```
