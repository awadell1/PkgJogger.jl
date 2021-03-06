# Saving and Loading Results

Benchmarking results can be saved / loaded using
[`PkgJogger.save_benchmarks`](@ref) and [`PkgJogger.load_benchmarks`](@ref).
These methods build on
[BenchmarkTools'](https://github.com/JuliaCI/BenchmarkTools.jl) offering by:

- Compressing the output file using `gzip`
- Additional information such as:
  - Julia Version, Commit and Build Date
  - System Information (Essentially everything in `Sys`)
  - Timestamp when the results get saved
  - Git Information, if run from a Git Repository
  - The version of PkgJogger used to save the results

Overall the resulting files are ~10x smaller, despite capturing additional information.

## Saving with JogPkgName

In addition to [`PkgJogger.save_benchmarks`](@ref), the generated `JogPkgName`
module provides `JogPkgName.save_benchmarks` for saving results to a consistent
location.

```julia
using AwesomePkg
using PkgJogger

# Run AwesomePkg's Benchmarks
@jog AwesomePkg
results = JogAwesomePkg.benchmark()

# Saves results to BENCH_DIR/trial/UUID.bson.gz and returns the filename used
JogAwesomePkg.save_benchmarks(results)

# Or run and save the benchmarks in a single step, the filename saved to
# will be reported in an @info message
JogAwesomePkg.benchmark(; save = true)

```

See also: [`JogExample.save_benchmarks`](@ref)

## Methods

```@docs
PkgJogger.save_benchmarks
PkgJogger.load_benchmarks
```
