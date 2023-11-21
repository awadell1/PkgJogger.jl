# Profiling Benchmarks

PkgJogger has support for profiling existing benchmarks using one of the [Supported Profilers](#supported-profilers),
support for profiling is currently limited. Notably:

1. Only a single benchmark can be profiled at a time
2. Automated saving or loading of profile results is not supported

## Supported Profilers


### CPU
```@docs
PkgJogger.profile(::Val{:cpu}, ::Any, ::PkgJogger.BenchmarkTools.Benchmark)
```

### Allocations

```@docs
PkgJogger.profile(::Val{:allocs}, ::Any, ::PkgJogger.BenchmarkTools.Benchmark)
```

### GPU

```@docs
PkgJogger.profile(::Val{:cuda}, ::Any, ::PkgJogger.BenchmarkTools.Benchmark)
```
