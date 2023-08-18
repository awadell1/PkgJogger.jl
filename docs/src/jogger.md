# Generated Jogger Modules

At its core, `PkgJogger` uses meta-programming to generate a Jogger module for
running a package's benchmarks. For example, calling `@jog` on `Example` gives
a jogger named `JogExample` for running the benchmark suite of `Example`:

```jldoctest
julia> using PkgJogger, Example

julia> @jog Example
JogExample

```

Similarly, `@jog AwesomePkg` would create a module named `JogAwesomePkg`:

```@docs
PkgJogger.@jog
```

## Benchmark Directory Structure

`PkgJogger` will recursively search the package's `benchmark/` directory
for benchmarking files `bench_*.jl` or directories `bench_*/`.

For example, the following directory:

```
.
+-- Project.toml
+-- src/
|   +-- PkgName.j;
|   ...
+-- benchmark
    +-- bench_matrix.jl # Will be included
    ....
    +-- subdir/     # ignored
    +-- bench_ui/   # This gets added
        +-- bench_foo.jl
        ....
```

Results in a benchmarking suite of:
```
1-element BenchmarkTools.BenchmarkGroup:
    "bench_matrix.jl" => Suite from "benchmark/bench_matrix.jl"
    ... # Other benchmark/bench_*.jl files
    "bench_ui" => BenchmarkTools.BenchmarkGroup:
        "bench_foo.jl" => Suite from "benchmark/bench_ui/bench_foo.jl"
        ... # Other benchmark/bench_ui/bench_*.jl files
```

## Benchmark Files

`PkgJogger` expects the following structure for benchmarking files:

```julia
# PkgJogger will wrap this file into a module, thus it needs to declare all of
# it's `using` and `import` statements.
using BenchmarkTools
using OtherPkg
using AweseomePkg

# PkgJogger assumes the first `suite` variable is the benchmark suite for this file
suite = BenchmarkGroup()

# This will add a benchmark "foo" to the benchmarking suite with a key of:
# ["bench_filename.jl", "foo"]
suite["foo"] = @benchmarkable ...

# Further nesting within the file's `suite` is possible
s = suite["baz"] = BenchmarkGroup()
s["bar"] = @benchmarkable ... # Key of ["bench_filename.jl", "baz", "bar"]
```

In the example, we assume the benchmarking file is `benchmark/bench_filename.jl`.
If it was located in a subdirectory `benchmark/bench_subdir` the resulting suite
would have keys of `["bench_subdir", "bench_filename.jl", ...]`, instead of
`["bench_filename.jl", ...]`. as shown.

!!! tip
    The upside of this structure is each benchmark file is self-contained
    and independent of other benchmarking files. For example:

    ```julia
    include("benchmark/bench_filename.jl")
    tune!(suite)
    run(suite)
    ```

## Jogger Reference

Jogger modules provide helper methods for working with their package's
benchmarking suite. For reference, this section documents the methods for `@jog
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
