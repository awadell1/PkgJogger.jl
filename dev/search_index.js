var documenterSearchIndex = {"docs":
[{"location":"ci/#Continuous-Benchmarking","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger provides a quick one-liner for setting up, running, and saving benchmarking results as part of a CI/CD pipeline:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); using PkgJogger; PkgJogger.ci()'","category":"page"},{"location":"ci/#Github-Actions","page":"Continuous Benchmarking","title":"Github Actions","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"name: PkgJogger\non:\n    - push\n    - pull_request\n\njobs:\n    benchmark:\n        runs-on: ubuntu-latest\n        steps:\n            - uses: actions/checkout@v2\n            - uses: julia-actions/setup-julia@latest\n            - name: Run Benchmarks\n              run: julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); using PkgJogger; PkgJogger.ci()'\n            - uses: actions/upload-artifact@v2\n              with:\n                name: benchmarks\n                path: benchmark/trial/*\n","category":"page"},{"location":"ci/#Isolated-Benchmarking-Environment","page":"Continuous Benchmarking","title":"Isolated Benchmarking Environment","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger will create a temporary environment with the following:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"Activate a temporary Julia environment for benchmarking.\nIf a Julia project file exists in benchmark/, it will be copied to the temporary environment. Manifest files are currently ignored.\nOtherwise, an empty environment is created.\nAdd the current project (via Pkg.develop) to the benchmarking environment and resolve dependencies using PRESEVE_NONE.\nAdd PkgJogger and resolve dependencies using PRESERVE_TIERED.\nStrip the LOAD_PATH to the benchmarking environment. The prior LOAD_PATH is restored after benchmarking.","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"This results in an isolated environment with the following properties:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"Minimizes PkgJogger's impact on dependency resolution.\nPackages not explicitly added by Project.toml or benchmark/Project.toml are not available in the benchmarking environment.","category":"page"},{"location":"ci/#Testing-Benchmarks","page":"Continuous Benchmarking","title":"Testing Benchmarks","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"Often benchmarking suites are too large to be included in unit testing, or PkgJogger.ci may be too costly to run with each push/pr/etc. However, regressions are inevitable without continuous testing as changes inadvertently break the benchmark suite. To help with this, PkgJogger provides the @test_benchmarks as a smoke test for possible breakages.","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger.@test_benchmarks","category":"page"},{"location":"ci/#PkgJogger.@test_benchmarks","page":"Continuous Benchmarking","title":"PkgJogger.@test_benchmarks","text":"@test_benchmarks PkgName\n\nCollects all benchmarks for PkgName, and test that they don't error when ran once.\n\nExample\n\njulia> using PkgJogger, Example\n\njulia> @test_benchmarks Example\n│ Test Summary:  | Pass  Total\n│ bench_timer.jl |    2      2\n[...]\n\nTesting\n\nEach benchmark is wrapped in a @testset, run only once, and marked as passing iff no errors are raised. This provides a fast smoke test for a benchmarking suite, and avoids the usual cost of tunning, warming up and collecting samples accrued when actually benchmarking.\n\nBenchmark Loading\n\nLocating benchmarks for testing is the same as for @jog and can be examined using PkgJogger.locate_benchmarks.\n\n\n\n\n\n","category":"macro"},{"location":"ci/#Reference","page":"Continuous Benchmarking","title":"Reference","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger.ci\nPkgJogger.JOGGER_PKGS","category":"page"},{"location":"ci/#PkgJogger.ci","page":"Continuous Benchmarking","title":"PkgJogger.ci","text":"Sets up an isolated benchmarking environment and then runs the following:\n\nusing PkgJogger\nusing PkgName\njogger = @jog PkgName\nresult = JogPkgName.benchmark()\nfilename = JogPkgName.save_benchmarks(result)\n@info \"Saved benchmarks to $filename\"\n\n\nWhere PkgName is the name of the package in the current directory\n\n\n\n\n\n","category":"function"},{"location":"ci/#PkgJogger.JOGGER_PKGS","page":"Continuous Benchmarking","title":"PkgJogger.JOGGER_PKGS","text":"Packages that are required by modules created with @jog\n\nGenerated modules will access these via Base.loaded_modules\n\n\n\n\n\n","category":"constant"},{"location":"jogger/#Generated-Jogger-Modules","page":"Jogger","title":"Generated Jogger Modules","text":"","category":"section"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"At its core, PkgJogger uses meta-programming to generate a Jogger module for running a package's benchmarks. For example, calling @jog on Example gives a jogger named JogExample for running the benchmark suite of Example:","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"julia> using PkgJogger, Example\n\njulia> @jog Example\nJogExample\n","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"Similarly, @jog AwesomePkg would create a module named JogAwesomePkg:","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"PkgJogger.@jog","category":"page"},{"location":"jogger/#PkgJogger.@jog","page":"Jogger","title":"PkgJogger.@jog","text":"@jog PkgName\n\nCreates a module named JogPkgName for running benchmarks for PkgName.\n\nMost edits to benchmark files are correctly tracked by Revise.jl. If they are not, re-run @jog PkgName to fully reload JogPkgName.\n\nMethods\n\nsuite       Return a BenchmarkGroup of the benchmarks for PkgName\nbenchmark   Warmup, tune and run the suite\nrun         Dispatch to BenchmarkTools.run(suite(), args...; kwargs...)\nwarmup      Dispatch to BenchmarkTools.warmup(suite(), args...; kwargs...)\nsave_benchmarks     Save benchmarks for PkgName using an unique filename\n\nIsolated Benchmarks\n\nEach benchmark file, is wrapped in it's own module preventing code loaded in one file from being visible in another (unless explicitly included).\n\nExample\n\nusing AwesomePkg, PkgJogger\n@jog AwesomePkg\nresults = JogAwesomePkg.benchmark()\nfile = JogAwesomePkg.save_benchmarks(results)\n\n\n\n\n\n","category":"macro"},{"location":"jogger/#Benchmark-Directory-Structure","page":"Jogger","title":"Benchmark Directory Structure","text":"","category":"section"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"PkgJogger will recursively search the package's benchmark/ directory for benchmarking files bench_*.jl or directories bench_*/.","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"For example, the following directory:","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":".\n+-- Project.toml\n+-- src/\n|   +-- PkgName.j;\n|   ...\n+-- benchmark\n    +-- bench_matrix.jl # Will be included\n    ....\n    +-- subdir/     # ignored\n    +-- bench_ui/   # This gets added\n        +-- bench_foo.jl\n        ....","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"Results in a benchmarking suite of:","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"1-element BenchmarkTools.BenchmarkGroup:\n    \"bench_matrix.jl\" => Suite from \"benchmark/bench_matrix.jl\"\n    ... # Other benchmark/bench_*.jl files\n    \"bench_ui\" => BenchmarkTools.BenchmarkGroup:\n        \"bench_foo.jl\" => Suite from \"benchmark/bench_ui/bench_foo.jl\"\n        ... # Other benchmark/bench_ui/bench_*.jl files","category":"page"},{"location":"jogger/#Benchmark-Files","page":"Jogger","title":"Benchmark Files","text":"","category":"section"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"PkgJogger expects the following structure for benchmarking files:","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"# PkgJogger will wrap this file into a module, thus it needs to declare all of\n# it's `using` and `import` statements.\nusing BenchmarkTools\nusing OtherPkg\nusing AweseomePkg\n\n# PkgJogger assumes the first `suite` variable is the benchmark suite for this file\nsuite = BenchmarkGroup()\n\n# This will add a benchmark \"foo\" to the benchmarking suite with a key of:\n# [\"bench_filename.jl\", \"foo\"]\nsuite[\"foo\"] = @benchmarkable ...\n\n# Further nesting within the file's `suite` is possible\ns = suite[\"baz\"] = BenchmarkGroup()\ns[\"bar\"] = @benchmarkable ... # Key of [\"bench_filename.jl\", \"baz\", \"bar\"]","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"In the example, we assume the benchmarking file is benchmark/bench_filename.jl. If it was located in a subdirectory benchmark/bench_subdir the resulting suite would have keys of [\"bench_subdir\", \"bench_filename.jl\", ...], instead of [\"bench_filename.jl\", ...]. as shown.","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"A side effect of this structure is that each benchmarking file is self-contained and independent of other benchmarking files. This means that if you want to run the suite of a single file, you can include the file and run it with: tune!(suite); run(suite)","category":"page"},{"location":"jogger/#Jogger-Reference","page":"Jogger","title":"Jogger Reference","text":"","category":"section"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"Jogger modules provide helper methods for working with their package's benchmarking suite. For reference, this section documents the methods for @jog Example.","category":"page"},{"location":"jogger/","page":"Jogger","title":"Jogger","text":"JogExample.suite\nJogExample.benchmark\nJogExample.warmup\nJogExample.run\nJogExample.save_benchmarks\nJogExample.load_benchmarks\nJogExample.judge\nJogExample.BENCHMARK_DIR","category":"page"},{"location":"jogger/#Main.JogExample.suite","page":"Jogger","title":"Main.JogExample.suite","text":"suite()::BenchmarkGroup\n\nThe BenchmarkTools suite for Example\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.benchmark","page":"Jogger","title":"Main.JogExample.benchmark","text":"benchmark(; verbose = false, save = false, ref = nothing)\n\nWarmup, tune and run the benchmarking suite for Example.\n\nIf save = true, will save the results using JogExample.save_benchmarks and display the filename using @info.\n\nTo reuse prior tuning results set ref to a BenchmarkGroup or suitable identifier for JogExample.load_benchmarks. See PkgJogger.tune! for more information about re-using tuning results.\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.warmup","page":"Jogger","title":"Main.JogExample.warmup","text":"warmup(; verbose::Bool = false)\n\nWarmup the benchmarking suite for Example\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.run","page":"Jogger","title":"Main.JogExample.run","text":"run(args...; verbose::Bool = false, kwargs)\n\nRun the benchmarking suite for Example. See BenchmarkTools.run for more options\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.save_benchmarks","page":"Jogger","title":"Main.JogExample.save_benchmarks","text":"save_benchmarks(results::BenchmarkGroup)::String\n\nSaves benchmarking results for Example to BENCHMARK_DIR/trial/uuid4().bson.gz, and returns the path to the saved results\n\nMeta Data such as cpu load, time stamp, etc. are collected on save, not during benchmarking. For representative metadata, results should be saved immediately after benchmarking.\n\nResults can be loaded with PkgJogger.load_benchmarks or JogExample.load_benchmarks\n\nExample\n\nRunning a benchmark suite and then saving the results\n\nr = JogExample.benchmark()\nfilename = JogExample.save_benchmarks(r)\n\nEquivalently: JogExample.benchmark(; save = true)\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.load_benchmarks","page":"Jogger","title":"Main.JogExample.load_benchmarks","text":"load_benchmarks(id)::Dict\n\nLoads benchmarking results for Example from BENCHMARK_DIR/trial based on id. The following are supported id types:\n\n- `filename::String`: Loads results from `filename`\n- `uuid::Union{String, UUID}`: Loads results with the given UUID\n- `:latest` loads the latest (By mtime) results from `BENCHMARK_DIR/trial`\n- `:oldest` loads the oldest (By mtime) results from `BENCHMARK_DIR/trial`\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.judge","page":"Jogger","title":"Main.JogExample.judge","text":"judge(new, old; metric=Statistics.median, kwargs...)\n\nCompares benchmarking results from new vs old for regressions/improvements using metric as a basis. Additional kwargs are passed to BenchmarkTools.judge\n\nIdentical to PkgJogger.judge, but accepts any identifier supported by JogExample.load_benchmarks\n\nExamples\n\n# Judge the latest results vs. the oldest\nJogExample.judge(:latest, :oldest)\n[...]\n\n# Judge results by UUID\nJogExample.judge(\"67169071-b587-4c95-8ba8-4e6fbd4a710f\", \"2af17c8c-bbb0-4668-a35f-584d8c718f40\")\n[...]\n\n# Judge using the minimum, instead of the median, time\nJogExample.judge(\"path/to/results.bson.gz\", \"1077896c-880d-4dd9-8e05-3f12d96afbff\"; metric=minimum)\n[...]\n\n\n\n\n\n","category":"function"},{"location":"jogger/#Main.JogExample.BENCHMARK_DIR","page":"Jogger","title":"Main.JogExample.BENCHMARK_DIR","text":"BENCHMARK_DIR\n\nDirectory of benchmarks for Example\n\n\n\n\n\n","category":"constant"},{"location":"reference/#Utilities","page":"Reference","title":"Utilities","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"PkgJogger.benchmark_dir\nPkgJogger.locate_benchmarks\nPkgJogger.judge\nPkgJogger.test_benchmarks\nPkgJogger.tune!","category":"page"},{"location":"reference/#PkgJogger.benchmark_dir","page":"Reference","title":"PkgJogger.benchmark_dir","text":"benchmark_dir(pkg::Module)\nbenchmark_dir(pkg::PackageSpec)\nbenchmark_dir(project_path::String)\n\nReturns the absolute path of the benchmarks folder for pkg.\n\nSupported Benchmark Directories:\n\nPKG_DIR/benchmark\n\n\n\n\n\n","category":"function"},{"location":"reference/#PkgJogger.locate_benchmarks","page":"Reference","title":"PkgJogger.locate_benchmarks","text":"locate_benchmarks(pkg::Module)\nlocate_benchmarks(path::String, name=String[])\n\nReturns a list of BenchModule for identified benchmark files\n\n\n\n\n\n","category":"function"},{"location":"reference/#PkgJogger.judge","page":"Reference","title":"PkgJogger.judge","text":"judge(new, old; metric=Statistics.median, kwargs...)\n\nCompares benchmarking results from new vs old for regressions/improvements using metric as a basis. Additional kwargs are passed to BenchmarkTools.judge\n\nEffectively a convenience wrapper around load_benchmarks and BenchmarkTools.judge\n\nnew and old can be any one of the following:     - Filename of benchmarking results saved by PkgJogger     - A Dict as returned by PkgJogger.load_benchmarks(filename)     - A BenchmarkTools.BenchmarkGroup with benchmarking results\n\n\n\n\n\n","category":"function"},{"location":"reference/#PkgJogger.test_benchmarks","page":"Reference","title":"PkgJogger.test_benchmarks","text":"test_benchmarks(s::BenchmarkGroup)\n\nRuns a @testsuite for each benchmark in s once (One evaluation of the benchmark's target) Sub-benchmark groups / benchmarks are recursively wrapped in @testsuites for easy identification.\n\nbenchmarks are marked as \"passing\" if they don't error during evaluation.\n\n\n\n\n\n","category":"function"},{"location":"reference/#PkgJogger.tune!","page":"Reference","title":"PkgJogger.tune!","text":"tune!(group::BenchmarkGroup, ref::BenchmarkGroup; verbose::Bool=false)\n\nTunes a BenchmarkGroup, only tunning benchmarks not found in ref, otherwise reuse tuning results from the reference BenchmarkGroup, by copying over all benchmark parameters from ref.\n\nThis can reduce benchmarking runtimes significantly by only tuning new benchmarks. But does ignore the following:     - Changes to benchmarking parameters (ie. memory_tolerance) between group and ref     - Significant changes in performance, such that re-tunning is warranted     - Other changes (ie. changing machines), such that re-tunning is warranted\n\n\n\n\n\n","category":"function"},{"location":"reference/#Internal","page":"Reference","title":"Internal","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"PkgJogger.build_module","category":"page"},{"location":"reference/#PkgJogger.build_module","page":"Reference","title":"PkgJogger.build_module","text":"build_module(s::BenchModule)\n\nConstruct a module wrapping the BenchmarkGroup defined by s::BenchModule\n\n\n\n\n\n","category":"function"},{"location":"","page":"Home","title":"Home","text":"EditURL = \"/home/runner/work/PkgJogger.jl/PkgJogger.jl/docs/../README.md\"","category":"page"},{"location":"#PkgJogger","page":"Home","title":"PkgJogger","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"(Image: Stable) (Image: Dev) (Image: Build Status) (Image: Coverage Status)","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: version) (Image: pkgeval) (Image: PkgJogger Downloads)","category":"page"},{"location":"","page":"Home","title":"Home","text":"PkgJogger provides a framework for running suites of BenchmarkTools.jl benchmarks without the boilerplate.","category":"page"},{"location":"#Just-write-benchmarks","page":"Home","title":"Just write benchmarks","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Create a benchmark/bench_*.jl file, define a BenchmarkTools.jl suite and go!","category":"page"},{"location":"","page":"Home","title":"Home","text":"using BenchmarkTools\nusing AwesomePkg\nsuite = BenchmarkGroup()\nsuite[\"fast\"] = @benchmarkable fast_code()","category":"page"},{"location":"","page":"Home","title":"Home","text":"PkgJogger will wrap each benchmark/bench_*.jl in a module and bundle them into JogAwesomePkg","category":"page"},{"location":"","page":"Home","title":"Home","text":"using AwesomePkg\nusing PkgJogger\n\n# Creates the JogAwesomePkg module\n@jog AwesomePkg\n\n# Warmup, tune, and run all of AwesomePkg's benchmarks\nJogAwesomePkg.benchmark()","category":"page"},{"location":"#Benchmark,-Revise,-and-Benchmark-Again!","page":"Home","title":"Benchmark, Revise, and Benchmark Again!","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"PkgJogger uses Revise.jl to track changes to your benchmark/bench_*.jl files and reload your suite as you edit. No more waiting for benchmarks to precompile!","category":"page"},{"location":"","page":"Home","title":"Home","text":"Tracked Changes:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Changing your benchmarked function\nChanging benchmarking parameters (i.e. seconds or samples)\nAdding new benchmarks","category":"page"},{"location":"","page":"Home","title":"Home","text":"Current Limitations:","category":"page"},{"location":"","page":"Home","title":"Home","text":"New benchmark files are not tracked\nDeleted benchmarks will stick around\nRenamed benchmarks will create a new benchmark and retain the old name","category":"page"},{"location":"","page":"Home","title":"Home","text":"To get around the above, run @jog PkgName to get an updated jogger.","category":"page"},{"location":"#Continuous-Benchmarking-Baked-In!","page":"Home","title":"Continuous Benchmarking Baked In!","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Install PkgJogger, run benchmarks, and save results to a *.bson.gz with a one-line command.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); using PkgJogger; PkgJogger.ci()'","category":"page"},{"location":"","page":"Home","title":"Home","text":"What gets done:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Constructs a temporary benchmarking environment from Project.toml and benchmark/Project.toml.\nCreates a jogger to run the package's benchmarks.\nWarmup, tune and run all benchmarks.\nSave Benchmarking results and more to a compressed *.bson.gz file.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Or for a more lightweight option, use @test_bechmarks to run each benchmark once (No Warmup, tuning, etc.), as a smoke test against benchmarking regressions.","category":"page"},{"location":"io/#Saving-and-Loading-Results","page":"Saving Results","title":"Saving and Loading Results","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Benchmarking results can be saved / loaded using PkgJogger.save_benchmarks and PkgJogger.load_benchmarks. These methods build on BenchmarkTools' offering by:","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Compressing the output file using gzip\nAdditional information such as:\nJulia Version, Commit and Build Date\nSystem Information (Essentially everything in Sys)\nTimestamp when the results get saved\nGit Information, if run from a Git Repository\nThe version of PkgJogger used to save the results","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Overall the resulting files are ~10x smaller, despite capturing additional information.","category":"page"},{"location":"io/#Saving-with-JogPkgName","page":"Saving Results","title":"Saving with JogPkgName","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"In addition to PkgJogger.save_benchmarks, the generated JogPkgName module provides JogPkgName.save_benchmarks for saving results to a consistent location.","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"using AwesomePkg\nusing PkgJogger\n\n# Run AwesomePkg's Benchmarks\n@jog AwesomePkg\nresults = JogAwesomePkg.benchmark()\n\n# Saves results to BENCH_DIR/trial/UUID.bson.gz and returns the filename used\nJogAwesomePkg.save_benchmarks(results)\n\n# Or run and save the benchmarks in a single step, the filename saved to\n# will be reported in an @info message\nJogAwesomePkg.benchmark(; save = true)\n","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"See also: JogExample.save_benchmarks","category":"page"},{"location":"io/#Methods","page":"Saving Results","title":"Methods","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"PkgJogger.save_benchmarks\nPkgJogger.load_benchmarks","category":"page"},{"location":"io/#PkgJogger.save_benchmarks","page":"Saving Results","title":"PkgJogger.save_benchmarks","text":"save_benchmarks(filename, results::BenchmarkGroup)\n\nSave benchmarking results to filename.bson.gz for later analysis.\n\nFile Contents\n\nJulia Version, Commit and Commit date\nSystem Information\nTimestamp\nBenchmarking Results\nGit Commit, 'Is Dirty' status and author datetime\nPkgJogger Version used to save the file\n\nFile Format:\n\nResults are saved as a gzip compressed BSON file and can be loaded with PkgJogger.load_benchmarks\n\n\n\n\n\n","category":"function"},{"location":"io/#PkgJogger.load_benchmarks","page":"Saving Results","title":"PkgJogger.load_benchmarks","text":"load_benchmarks(filename::String)::Dict\n\nLoad benchmarking results from filename\n\nPrior to v0.4 PkgJogger saved results as *.json.gz instead of *.bson.gz. This function supports both formats. However, the *.json.gz format is deprecated, and may not support all features.\n\n\n\n\n\n","category":"function"}]
}
