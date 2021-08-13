var documenterSearchIndex = {"docs":
[{"location":"ci/#Continuous-Benchmarking","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger provides a quick one-liner for setting up, running, and saving benchmarking results as part of a CI/CD pipeline:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); PkgJogger.ci()'","category":"page"},{"location":"ci/#Github-Actions","page":"Continuous Benchmarking","title":"Github Actions","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"name: PkgJogger\non:\n    - push\n    - pull_request\n\njobs:\n    benchmark:\n        runs-on: ubuntu-latest\n        steps:\n            - uses: actions/checkout@v2\n            - uses: julia-actions/setup-julia@latest\n            - name: Run Benchmarks\n              run: julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); PkgJogger.ci()'\n            - uses: actions/upload-artifact@v2\n              with:\n                name: benchmarks\n                path: benchmark/trial/*\n","category":"page"},{"location":"ci/#Isolated-Benchmarking-Environment","page":"Continuous Benchmarking","title":"Isolated Benchmarking Environment","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger will create a temporary environment with the following:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"Instantiate the current package\nIf found, instantiate benchmark/Project.toml and add to the LOAD_PATH\nAdd PkgJogger while preserving the resolved manifest\nRemove @stdlib and @v#.# from the LOAD_PATH","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"This results in an isolated environment with the following properties:","category":"page"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger does not dictate package resolution; the benchmarked package does\nPackages not explicitly added by Project.toml or benchmark/Project.toml","category":"page"},{"location":"ci/#Reference","page":"Continuous Benchmarking","title":"Reference","text":"","category":"section"},{"location":"ci/","page":"Continuous Benchmarking","title":"Continuous Benchmarking","text":"PkgJogger.ci\nPkgJogger.JOGGER_PKGS","category":"page"},{"location":"ci/#PkgJogger.ci","page":"Continuous Benchmarking","title":"PkgJogger.ci","text":"Sets up an isolated benchmarking environment and then runs the following:\n\nusing PkgJogger\nusing PkgName\njogger = @jog PkgName\nresult = JogPkgName.benchmark()\nfilename = JogPkgName.save_benchmarks(result)\n@info \"Saved benchmarks to $filename\"\n\n\nWhere PkgName is the name of the package in the current directory\n\n\n\n\n\n","category":"function"},{"location":"ci/#PkgJogger.JOGGER_PKGS","page":"Continuous Benchmarking","title":"PkgJogger.JOGGER_PKGS","text":"Packages that are required by modules created with @jog\n\nGenerated modules will access these via Base.loaded_modules\n\n\n\n\n\n","category":"constant"},{"location":"reference/","page":"Reference","title":"Reference","text":"PkgJogger.@jog\nPkgJogger.benchmark_dir\nPkgJogger.locate_benchmarks","category":"page"},{"location":"reference/#PkgJogger.@jog","page":"Reference","title":"PkgJogger.@jog","text":"@jog PkgName\n\nCreates a module named JogPkgName for running benchmarks for PkgName.\n\nMost edits to benchmark files are correctly tracked by Revise.jl. If they are not, re-run @jog PkgName to fully reload JogPkgName.\n\nMethods\n\nsuite       Return a BenchmarkGroup of the benchmarks for PkgName\nbenchmark   Warmup, tune and run the suite\nrun         Dispatch to BenchmarkTools.run(suite(), args...; kwargs...)\nwarmup      Dispatch to BenchmarkTools.warmup(suite(), args...; kwargs...)\nsave_benchmarks     Save benchmarks for PkgName using an unique filename\n\nIsolated Benchmarks\n\nEach benchmark file, is wrapped in it's own module preventing code loaded in one file from being visible in another (unless explicitly included).\n\nExample\n\nusing AwesomePkg, PkgJogger\n@jog AwesomePkg\nresults = JogAwesomePkg.benchmark()\nfile = JogAwesomePkg.save_benchmarks(results)\n\n\n\n\n\n","category":"macro"},{"location":"reference/#PkgJogger.benchmark_dir","page":"Reference","title":"PkgJogger.benchmark_dir","text":"benchmark_dir(pkg::Module)\nbenchmark_dir(pkg::PackageSpec)\nbenchmark_dir(project_path::String)\n\nReturns the absolute path of the benchmarks folder for pkg.\n\nSupported Benchmark Directories:\n\nPKG_DIR/benchmark\n\n\n\n\n\n","category":"function"},{"location":"reference/#PkgJogger.locate_benchmarks","page":"Reference","title":"PkgJogger.locate_benchmarks","text":"locate_benchmarks(pkg::Module)\nlocate_benchmarks(bench_dir::String)\n\nReturns a dict of name => filename of identified benchmark files\n\n\n\n\n\n","category":"function"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = PkgJogger","category":"page"},{"location":"#PkgJogger","page":"Home","title":"PkgJogger","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"A Benchmarking Framework for Julia","category":"page"},{"location":"","page":"Home","title":"Home","text":"PkgJogger makes benchmarking easy by providing a framework for running BenchmarkTool.jl benchmarks without the boilerplate.","category":"page"},{"location":"#Just-write-benchmarks","page":"Home","title":"Just write benchmarks","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Create a benchmark/bench_*.jl file, define a suite and go!","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Benchmark\nusing AwesomePkg\nsuite = BenchmarkGroup()\nsuite[\"fast\"] = @benchmarkable fast_code()","category":"page"},{"location":"","page":"Home","title":"Home","text":"PkgJogger will wrap each benchmark/bench_*.jl in a module and bundle them into JogAwesomePkg","category":"page"},{"location":"","page":"Home","title":"Home","text":"using AwesomePkg\nusing PkgJogger\n\n# Creates the JogAwesomePkg module\n@jog AwesomePkg\n\n# Warmup, tune, and run all of AwesomePkg's benchmarks\nJogAwesomePkg.benchmark()","category":"page"},{"location":"#Benchmark,-Revise,-and-Benchmark-Again!","page":"Home","title":"Benchmark, Revise, and Benchmark Again!","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"PkgJogger uses Revise.jl to track changes to your benchmark/bench_*.jl files and reload your suite as you edit. No more waiting for benchmarks to precompile!","category":"page"},{"location":"","page":"Home","title":"Home","text":"Tracked Changes:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Changing your benchmarked function\nChanging benchmarking parameters (i.e. seconds or samples)\nAdding new benchmarks","category":"page"},{"location":"","page":"Home","title":"Home","text":"Current Limitations:","category":"page"},{"location":"","page":"Home","title":"Home","text":"New benchmark files are not tracked\nDeleted benchmarks will stick around\nRenamed benchmarks will create a new benchmark and retain the old name","category":"page"},{"location":"","page":"Home","title":"Home","text":"To get around the above, run @jog PkgName to get an updated jogger.","category":"page"},{"location":"#Continuous-Benchmarking-Baked-In!","page":"Home","title":"Continuous Benchmarking Baked In!","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Install PkgJogger, run benchmarks, and save results to a *.json.gz with a one-line command.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia -e 'using Pkg; Pkg.add(\"PkgJogger\"); PkgJogger.ci()'","category":"page"},{"location":"","page":"Home","title":"Home","text":"What gets done:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Add the package at pwd() to a temporary environment\nIf found, instantiate benchmark/Project.toml and add to the LOAD_PATH\nAdd PkgJogger to the environment and build JogPkgName for your package\nWarmup, tune and run all benchmarks\nSave Benchmarking results and more to a compressed *.json.gz file","category":"page"},{"location":"io/#Saving-and-Loading-Results","page":"Saving Results","title":"Saving and Loading Results","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Benchmarking results can be saved / loaded using PkgJogger.save_benchmarks and PkgJogger.load_benchmarks. These methods build on BenchmarkTools' offering by:","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Compressing the output file using gzip\nAdditional information such as:\nJulia Version, Commit and Build Date\nSystem Information (Essentially everything in Sys)\nTimestamp of when the results were saved","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Overall the resulting files are ~10x smaller, despite capturing additional information.","category":"page"},{"location":"io/#Saving-with-JogPkgName","page":"Saving Results","title":"Saving with JogPkgName","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"In addition to PkgJogger.save_benchmarks, the generated JogPkgName module provides JogPkgName.save_benchmarks for saving results to a consistent location.","category":"page"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"using AwesomePkg\nusing PkgJogger\n\n# Run AwesomePkg's Benchmarks\n@jog AwesomePkg\nresults = JogAwesomePkg.benchmark()\n\n# Saves results to BENCH_DIR/trial/UUID.json.gz and returns the filename used\nJogAwesomePkg.save_benchmarks(results)","category":"page"},{"location":"io/#Methods","page":"Saving Results","title":"Methods","text":"","category":"section"},{"location":"io/","page":"Saving Results","title":"Saving Results","text":"Modules = [PkgJogger]\nPages = [\"utils.jl\"]","category":"page"},{"location":"io/#PkgJogger.ci-Tuple{}","page":"Saving Results","title":"PkgJogger.ci","text":"Sets up an isolated benchmarking environment and then runs the following:\n\nusing PkgJogger\nusing PkgName\njogger = @jog PkgName\nresult = JogPkgName.benchmark()\nfilename = JogPkgName.save_benchmarks(result)\n@info \"Saved benchmarks to $filename\"\n\n\nWhere PkgName is the name of the package in the current directory\n\n\n\n\n\n","category":"method"},{"location":"io/#PkgJogger.load_benchmarks-Tuple{Any}","page":"Saving Results","title":"PkgJogger.load_benchmarks","text":"load_benchmarks(filename::String)::Dict\n\nLoad benchmarking results from filename\n\n\n\n\n\n","category":"method"},{"location":"io/#PkgJogger.save_benchmarks-Tuple{Any, BenchmarkTools.BenchmarkGroup}","page":"Saving Results","title":"PkgJogger.save_benchmarks","text":"save_benchmarks(filename, results::BenchmarkGroup)\n\nSave benchmarking results to filename.json.gz for later analysis.\n\nFile Contents\n\nJulia Version, Commit and Commit date\nSystem Information\nTimestamp\nBenchmarking Results\n\nFile Format:\n\nResults are saved as a gzip compressed JSON file and can be loaded with PkgJogger.load_benchmarks\n\n\n\n\n\n","category":"method"}]
}
