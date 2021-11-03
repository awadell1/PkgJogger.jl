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

    # Run in sandbox
    pkgname = Symbol(pkg.name)
    jogger = Symbol(:Jog, pkg.name)
    sandbox(pkg) do
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

function sandbox(f, pkg)
    # Save current project and load path
    current_project = Pkg.project()
    current_load_path = Base.LOAD_PATH

    # Construct PackageSpec for self
    self = PackageSpec(
        name = JOGGER_PKGS[1].name,
        uuid = JOGGER_PKGS[1].uuid,
    )

    # Locate benchmark project
    # TODO: Use Sub-project https://github.com/JuliaLang/Pkg.jl/issues/1233
    bench_dir = benchmark_dir(pkg)
    bench_project = joinpath(bench_dir, Base.current_project(bench_dir))

    # Create a temporary environment
    mktempdir() do temp_env
        # Copy benchmarking project over iff it exists
        if isfile(bench_project)
            cp(bench_project, joinpath(temp_env, basename(bench_project)))
        end

        # Build up benchmarked environment
        Pkg.activate(temp_env; io=devnull)
        Pkg.develop(pkg; preserve=PRESERVE_NONE, io=devnull)
        Pkg.add(self; preserve=PRESERVE_TIERED, io=devnull)
        Pkg.instantiate(; io=devnull)

        # Strip LOAD_PATH to the temporary environment
        empty!(Base.LOAD_PATH)
        push!(Base.LOAD_PATH, "@")

        # Report current status
        Pkg.status(;mode=PKGMODE_MANIFEST)

        # Run function
        f()
    end

    # Restore environment and load path
    empty!(Base.LOAD_PATH)
    append!(Base.LOAD_PATH, current_load_path)
    Pkg.activate(current_project.path)
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
- Git Commit, 'Is Dirty' status and author datetime

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
        "datetime" => string(Dates.now()),
        "benchmarks" => results,
        "git" => git_info(filename),
    )

    # Write benchmark to disk
    open(GzipCompressorStream, filename, "w") do io
        JSON.print(io, out)
    end
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

function find_git_repo(path)
    if isdir(joinpath(path, ".git"))
        return path
    end
    next = dirname(path)
    if next != path
        return find_git_repo(next)
    else
        return nothing
    end
end

function git_info(path)
    # Check if path is a git repo
    ref_dir = isdir(path) ? path : dirname(path)
    ref_dir = find_git_repo(path)
    if ref_dir === nothing
        return nothing
    end

    # Get Head Commit
    head = LibGit2.peel(LibGit2.GitCommit, LibGit2.head(GitRepo(ref_dir)))
    author_sig = LibGit2.author(head)

    # Capture Git Info
    Dict(
        "commit" => LibGit2.GitHash(head) |> string,
        "is_dirty" =>  LibGit2.with(LibGit2.isdirty, GitRepo(ref_dir)),
        "datetime" => Dates.unix2datetime(author_sig.time) |> string,
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
