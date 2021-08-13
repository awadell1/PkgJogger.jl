"""
    ci()

Runs CI workflow for the current directory

```shell
julia -e 'using Pkg; Pkg.add("PkgJogger"); PkgJogger.ci()'
```

Will do the following:

"""

function ci()
    # Locate the project being benchmarked
    pkg = Pkg.Types.EnvCache(Base.current_project()).pkg

    # Look for a benchmark project, and add to LOAD_PATH if it exists
    # TODO: Use Sub-project https://github.com/JuliaLang/Pkg.jl/issues/1233
    bench_dir = benchmark_dir(pkg.path)
    benchmark_project = Base.env_project_file(bench_dir)
    load_path = String[]
    if isfile(benchmark_project)
        @info "Found benchmark project: $benchmark_project"
        push!(load_path, bench_dir)
    end

    # Instantiate Projects
    instantiate.(vcat([pkg.path], load_path))

    # Run in sandbox
    pkgname = Symbol(pkg.name)
    jogger = Symbol(:Jog, pkg.name)
    sandbox(pkg, load_path) do
        @eval Main begin
            using PkgJogger
            using $pkgname
            jogger = @jog $pkgname
            result = $jogger.benchmark()
            filename = $jogger.save_benchmarks(result)
            @info "Saved benchmarks to $filename"
        end
    end
end

function sandbox(f, pkg, load_path)
    # Save current project and load path
    current_project = Pkg.project()
    current_load_path = Base.LOAD_PATH

    # Build temporary environment
    # Add the project being benchmarked, then JOGGER_PKGS restricted to existing
    # manifest. Ie. The benchmarked projects drives compat not PkgJogger
    Pkg.activate(;temp=true)
    Pkg.add(pkg; io=IOBuffer())
    Pkg.add(JOGGER_PKGS; preserve=PRESERVE_ALL, io=IOBuffer())
    Pkg.instantiate(; io=IOBuffer())

    # Update LOAD_PATH
    # Only load code from: Temp Environment or benchmark/Project.toml
    empty!(Base.LOAD_PATH)
    append!(Base.LOAD_PATH, vcat(["@"], load_path))

    # Report current status
    Pkg.status(;mode=PKGMODE_MANIFEST)
    @debug "LOAD_PATH: $(Base.LOAD_PATH)"

    # Run function
    f()

    # Restore environment and load path
    empty!(Base.LOAD_PATH)
    append!(Base.LOAD_PATH, current_load_path)
    Pkg.activate(current_project.path)
end

function instantiate(project_file)
    @info "Instantiating: $project_file"
    cur_project = Pkg.project().path
    Pkg.activate(project_file; io=IOBuffer())
    Pkg.instantiate(; io=IOBuffer())
    Pkg.activate(cur_project; io=IOBuffer())
end

"""
    save_benchmarks(filename, results::BenchmarkGroup)

Save benchmarking results to `filename.json.gz` for later
analysis.

## File Contents
- Julia Version, Commit and Commit date
- Manifest for the current project
- Benchmarking Results

## File Format:
Results are saved as a gzip compressed JSON file and can be loaded
with [PkgJogger.load_benchmarks](@ref PkgJogger.load_benchmarks)

"""
function save_benchmarks(filename, results::BenchmarkTools.BenchmarkGroup)
    # Collect system information to save
    mkpath(dirname(filename))
    out = Dict(
        "julia" => julia_info(),
        "manifest" => manifest_info(),
        "benchmarks" => results,
    )

    # Write benchmark to disk
    open(GzipCompressorStream, filename, "w") do io
        JSON.print(io, out)
    end
    filename
end

# Convenience Wrapper so JogPkgName doesn't required UUIDs to be loaded
function _save_jogger_benchmarks(dir, results::BenchmarkTools.BenchmarkGroup)
    filename = joinpath(dir, "$(UUIDs.uuid4()).json.gz")
    save_benchmarks(filename, results)
end

"""
    load_benchmarks(filename::String)::Dict

Load benchmarking results saved by [PkgJogger.save_benchmarks](@ref PkgJogger.save_benchmarks)
"""
function load_benchmarks(filename)
    # Decompress
    out = open(JSON.parse, GzipDecompressorStream, filename)

    # Recover BenchmarkTools Types
    if haskey(out, "benchmarks")
        out["benchmarks"] = BenchmarkTools.recover(out["benchmarks"])
    else
        error("Missing 'benchmarks' field in $filename")
    end
    out
end

function julia_info()
    Dict(
        :version => Base.VERSION,
        :commit => Base.GIT_VERSION_INFO.commit,
        :date => Base.GIT_VERSION_INFO.date_string,
    )
end

function manifest_info()
    manifest = Base.project_file_manifest_path(Base.current_project())
    Pkg.Types.read_manifest(manifest)
end

