# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [Unreleased](https://github.com/awadell1/PkgJogger.jl/compare/v0.5.1...HEAD)

- Added: define the public interface.
- Added: support profiling individual benchmarks.
- Added: support for selecting subsets in `judge`.
- Changed: expand compat to cover LTS; expand CUDA compat; be explicit about imports; use `juliaup` in CI.
- Fixed: handle empty-benchmarks case; correct lower bound on Revise.
- Documentation: add interlinks; ongoing docs work.

## [v0.5.1](https://github.com/awadell1/PkgJogger.jl/compare/v0.5.0...v0.5.1) - 2024-04-15

- Fixed: install PkgJogger in sandbox via `Pkg.add`.

## [v0.5.0](https://github.com/awadell1/PkgJogger.jl/compare/v0.4.2...v0.5.0) - 2024-02-28

- Breaking: remove warmup.
- Breaking: increase minimum Julia to 1.9.
- Changed: rework testing framework; CI/doc build updates (registry updates before resolve).
- Fixed: update registry steps in CI.

## [v0.4.2](https://github.com/awadell1/PkgJogger.jl/compare/v0.4.1...v0.4.2) - 2023-08-18

- Added: simplify CI action; install in base environment.
- Changed: update `actions/checkout@v3`; allow manually triggering CI.
- Maintenance: remove deprecated `save-state` usage; cleanups.

## [v0.4.1](https://github.com/awadell1/PkgJogger.jl/compare/v0.4.0...v0.4.1) - 2022-08-24

- Fixed: GitHub Action recipe to sandbox PkgJogger install.

## [v0.4.0](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.5...v0.4.0) - 2022-07-06

- Maintenance: release and CI improvements.

## [v0.3.5](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.4...v0.3.5) - 2022-01-06

- Maintenance: release and CI improvements.

## [v0.3.4](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.3...v0.3.4) - 2022-01-02

- Maintenance: release and CI improvements.

## [v0.3.3](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.2...v0.3.3) - 2021-12-12

- Maintenance: release and CI improvements.

## [v0.3.2](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.1...v0.3.2) - 2021-11-21

- Maintenance: release and CI improvements.

## [v0.3.1](https://github.com/awadell1/PkgJogger.jl/compare/v0.3.0...v0.3.1) - 2021-11-19

- Maintenance: release and CI improvements.

## [v0.3.0](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.5...v0.3.0) - 2021-11-19

- Maintenance: release and CI improvements.

## [v0.2.5](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.4...v0.2.5) - 2021-09-26

- Maintenance: release and CI improvements.

## [v0.2.4](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.3...v0.2.4) - 2021-09-07

- Maintenance: release and CI improvements.

## [v0.2.3](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.2...v0.2.3) - 2021-09-03

- Maintenance: release and CI improvements.

## [v0.2.2](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.1...v0.2.2) - 2021-08-17

- Maintenance: release and CI improvements.

## [v0.2.1](https://github.com/awadell1/PkgJogger.jl/compare/v0.2.0...v0.2.1) - 2021-08-17

- Maintenance: release and CI improvements.

## [v0.2.0](https://github.com/awadell1/PkgJogger.jl/compare/v0.1.0...v0.2.0) - 2021-08-14

- Maintenance: release and CI improvements.

## [v0.1.0](https://github.com/awadell1/PkgJogger.jl/releases/tag/v0.1.0) - 2021-08-14

- Initial release.

<!--
Comparison links
-->
[Unreleased]: https://github.com/awadell1/PkgJogger.jl/compare/v0.5.1...HEAD
[v0.5.1]: https://github.com/awadell1/PkgJogger.jl/compare/v0.5.0...v0.5.1
[v0.5.0]: https://github.com/awadell1/PkgJogger.jl/compare/v0.4.2...v0.5.0
[v0.4.2]: https://github.com/awadell1/PkgJogger.jl/compare/v0.4.1...v0.4.2
[v0.4.1]: https://github.com/awadell1/PkgJogger.jl/compare/v0.4.0...v0.4.1
[v0.4.0]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.5...v0.4.0
[v0.3.5]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.4...v0.3.5
[v0.3.4]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.3...v0.3.4
[v0.3.3]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.2...v0.3.3
[v0.3.2]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.1...v0.3.2
[v0.3.1]: https://github.com/awadell1/PkgJogger.jl/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.5...v0.3.0
[v0.2.5]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.4...v0.2.5
[v0.2.4]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.3...v0.2.4
[v0.2.3]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.1...v0.2.2
[v0.2.1]: https://github.com/awadell1/PkgJogger.jl/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/awadell1/PkgJogger.jl/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/awadell1/PkgJogger.jl/releases/tag/v0.1.0
