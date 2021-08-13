"""

Sets up an isolated benchmarking environment and then runs the following:

```julia
using PkgJogger
using PkgName
jogger = @jog PkgName
result = JogPkgName.benchmark()
filename = JogPkgName.save_benchmarks(result)
@info "Saved benchmarks to \$filename"

```

Where `PkgName` is the name of the package in the current directory

"""
function ci()
    # Locate the package being benchmarked
    project = Base.current_project()
    pkg_toml = Base.parsed_toml(project)
    pkg = Pkg.PackageSpec(
        name=pkg_toml["name"],
        uuid=pkg_toml["uuid"],
        path=dirname(project),
    )

    # Look for a benchmark project, and add to LOAD_PATH if it exists
    # TODO: Use Sub-project https://github.com/JuliaLang/Pkg.jl/issues/1233
    bench_dir = benchmark_dir(pkg)
    benchmark_project = Base.env_project_file(bench_dir)
    load_path = String[]
    if isfile(benchmark_project)
        @info "Found benchmark project: $benchmark_project"
        instantiate(bench_dir)
        push!(load_path, bench_dir)
    end

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
    Pkg.develop(pkg; io=devnull)
    Pkg.add(JOGGER_PKGS; preserve=PRESERVE_ALL, io=devnull)
    Pkg.instantiate(; io=devnull)

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
    Pkg.activate(project_file; io=devnull)
    Pkg.instantiate(; io=devnull)
    Pkg.activate(cur_project; io=devnull)
end

"""
    save_benchmarks(filename, results::BenchmarkGroup)

Save benchmarking results to `filename.json.gz` for later
analysis.

## File Contents
- Julia Version, Commit and Commit date
- System Information
- Timestamp
- Benchmarking Results

## File Format:
Results are saved as a gzip compressed JSON file and can be loaded
with [`PkgJogger.load_benchmarks`](@ref)

"""
function save_benchmarks(filename, results::BenchmarkTools.BenchmarkGroup)
    # Collect system information to save
    mkpath(dirname(filename))
    out = Dict(
        "julia" => julia_info(),
        "system" => system_info(),
        "datetime" =>string(Dates.now()),
        "benchmarks" => results,
    )

    # Write benchmark to disk
    open(GzipCompressorStream, filename, "w") do io
        JSON.print(io, out)
    end
end

# Convenience Wrapper so JogPkgName doesn't required UUIDs to be loaded
function _save_jogger_benchmarks(dir, results::BenchmarkTools.BenchmarkGroup)
    filename = joinpath(dir, "$(UUIDs.uuid4()).json.gz")
    save_benchmarks(filename, results)
    filename
end

function julia_info()
    Dict(
        :version => Base.VERSION,
        :commit => Base.GIT_VERSION_INFO.commit,
        :date => Base.GIT_VERSION_INFO.date_string,
    )
end

function system_info()
    Dict(
        "arch" => string(Sys.ARCH),
        "kernel" => string(Sys.KERNEL),
        "machine" => Sys.MACHINE,
        "jit" => Sys.JIT,
        "word_size" => Sys.WORD_SIZE,
        "cpu_threads" => Sys.CPU_THREADS,
        "cpu_info" => Sys.cpu_info(),
        "uptime" => Sys.uptime(),
        "loadavg" => Sys.loadavg(),
        "free_memory" => Sys.free_memory(),
        "total_memory" => Sys.total_memory()
    )
end

"""
    load_benchmarks(filename::String)::Dict

Load benchmarking results from `filename`
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


