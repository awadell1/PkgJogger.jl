# Continuous Benchmarking

PkgJogger provides a quick one-liner for setting up, running, and saving benchmarking
results as part of a CI/CD pipeline:

```shell
julia -e 'using Pkg; Pkg.add("PkgJogger"); using PkgJogger; PkgJogger.ci()'
```

## Github Actions

Just add `uses: awadell1/PkgJogger` and you're set! For example, the following
will setup julia, run the benchmarks and upload the results for later analysis:

```yaml
name: PkgJogger
on:
    - push
    - pull_request

jobs:
    benchmark:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v2
            - uses: julia-actions/setup-julia@latest
            - uses: awadell1/PkgJogger
            - uses: actions/upload-artifact@v2
              with:
                name: benchmarks
                path: benchmark/trial/*

```

## Isolated Benchmarking Environment

PkgJogger will create a temporary environment with the following:

1) Activate a temporary Julia environment for benchmarking.
    - If a Julia project file exists in `benchmark/`, it will be copied to the
      temporary environment. Manifest files are currently ignored.
    - Otherwise, an empty environment is created.
2) Add the current project (via `Pkg.develop`) to the benchmarking environment
   and resolve dependencies using
   [`PRESEVE_NONE`](https://pkgdocs.julialang.org/v1/api/#Pkg.add).
3) Add `PkgJogger` and resolve dependencies using
   [`PRESERVE_TIERED`](https://pkgdocs.julialang.org/v1/api/#Pkg.add).
4) Strip the
   [`LOAD_PATH`](https://docs.julialang.org/en/v1/base/constants/#Base.LOAD_PATH)
   to the benchmarking environment. The prior `LOAD_PATH` is restored after benchmarking.

This results in an isolated environment with the following properties:

- Minimizes PkgJogger's impact on dependency resolution.
- Packages not explicitly added by `Project.toml` or `benchmark/Project.toml`
  are not available in the benchmarking environment.

## Testing Benchmarks

Often benchmarking suites are too large to be included in unit testing,
or [`PkgJogger.ci`](@ref) may be too costly to run with each push/pr/etc.
However, regressions are inevitable without continuous testing as changes inadvertently break the benchmark suite.
To help with this, PkgJogger provides the [`@test_benchmarks`](@ref) as a smoke test for possible breakages.

```@docs
PkgJogger.@test_benchmarks
```

## Reference

```@docs
PkgJogger.ci
PkgJogger.JOGGER_PKGS
```
