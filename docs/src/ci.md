# Continuous Benchmarking

PkgJogger provides a quick one-liner for setting up, running, and saving benchmarking
results as part of a CI/CD pipeline:

```shell
julia -e 'using Pkg; Pkg.add("PkgJogger"); PkgJogger.ci()'
```

## Github Actions

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
            - name: Run Benchmarks
              run: julia -e 'using Pkg; Pkg.add("PkgJogger"); PkgJogger.ci()'
            - uses: actions/upload-artifact@v2
              with:
                name: benchmarks
                path: benchmark/trial/*

```

## Isolated Benchmarking Environment

PkgJogger will create a temporary environment with the following:

1) Instantiate the current package
2) If found, instantiate `benchmark/Project.toml` and add to the `LOAD_PATH`
3) Add PkgJogger while preserving the resolved manifest
4) Remove `@stdlib` and `@v#.#` from the `LOAD_PATH`

This results in an isolated environment with the following properties:

- PkgJogger does not dictate package resolution; the benchmarked package does
- Packages not explicitly added by `Project.toml` or `benchmark/Project.toml`

## Reference

```@docs
PkgJogger.ci
PkgJogger.JOGGER_PKGS
```
