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
    sandbox(pkg) do
        @eval Main begin
            using PkgJogger
            using $pkgname
            jogger = @jog $pkgname
            result = jogger.benchmark()
            filename = jogger.save_benchmarks(result)
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

Save benchmarking results to `filename.bson.gz` for later
analysis.

## File Contents
- Julia Version, Commit and Commit date
- System Information
- Timestamp
- Benchmarking Results
- Git Commit, 'Is Dirty' status and author datetime
- PkgJogger Version used to save the file

## File Format:
Results are saved as a gzip compressed BSON file and can be loaded
with [`PkgJogger.load_benchmarks`](@ref)
"""
function save_benchmarks(filename, results::BenchmarkTools.BenchmarkGroup)
    # Collect system information to save
    mkpath(dirname(filename))
    out = Dict(
        "julia" => julia_info(),
        "system" => system_info(),
        "datetime" => Dates.now(),
        "benchmarks" => results,
        "git" => git_info(filename),
        "pkgjogger" => PkgJogger.PKG_JOGGER_VER,
    )

    # Write benchmark to disk
    open(GzipCompressorStream, filename, "w") do io
        bson(io, out)
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

    # Attempt to get git info -> But Fall back to nothing on failure
    try
        # Get Head Commit
        head = LibGit2.peel(LibGit2.GitCommit, LibGit2.head(GitRepo(ref_dir)))
        author_sig = LibGit2.author(head)

        # Capture Git Info
        return Dict(
            "commit" => LibGit2.GitHash(head) |> string,
            "is_dirty" =>  LibGit2.with(LibGit2.isdirty, GitRepo(ref_dir)),
            "datetime" => Dates.unix2datetime(author_sig.time),
        )
    catch e
        if e isa LibGit2
            # Something went wrong with LibGit2
            @warn "Unable to get git info via LibGit2" exception=(e, catch_backtrace())
        else
            # Something went wrong with PkgJogger
            @error "Please open an issue with PkgJogger: https://github.com/awadell1/PkgJogger.jl/issues" exception=(e, catch_backtrace())
        end
        return nothing
    end
end

"""
    load_benchmarks(filename::String)::Dict

Load benchmarking results from `filename`

> Prior to v0.4 PkgJogger saved results as `*.json.gz` instead of `*.bson.gz`.
> This function supports both formats. However, the `*.json.gz` format is
> deprecated, and may not support all features.
"""
function load_benchmarks(filename::AbstractString)
    # Decompress
    if endswith(filename, ".json.gz")
        @warn "Legacy `*.json.gz` format is deprecated, some features may not be supported"
        reader = JSON.parse
    elseif endswith(filename, ".bson.gz")
        reader = io -> BSON.load(io, @__MODULE__)
    else
        error("Unsupported file format: $filename")
    end
    out = open(reader, GzipDecompressorStream, filename)

    # Get PkgJogger version
    version = haskey(out, "pkgjogger") ? out["pkgjogger"] : missing

    # Recover Benchmarking Results
    if ismissing(version)
        @assert haskey(out, "benchmarks") "Missing 'benchmarks' field in $filename"
        out["benchmarks"] = BenchmarkTools.recover(out["benchmarks"])
    end

    return out
end

# Possible file extensions for a PkgJogger file
const PKG_JOGGER_EXT = (".bson.gz", ".json.gz")

# Handle dispatch on UUIDs from Jogger
function load_benchmarks(trial_dir::AbstractString, uuid::UUIDs.UUID)
    for ext in PKG_JOGGER_EXT
        full_path = joinpath(trial_dir, string(uuid) * ext)
        if isfile(full_path)
            return load_benchmarks(full_path)
        end
    end
    error("Unable to find benchmarking results for $uuid in $trial_dir")
end

# Handle dispatch on a string from Jogger
function load_benchmarks(trial_dir, id::AbstractString)
    # Attempt to parse string as UUID -> If not, assume it is a filename
    uuid = Base.tryparse(UUID, id)
    isnothing(uuid) && return load_benchmarks(id)
    return load_benchmarks(trial_dir, uuid)
end

# Handle dispatch on a Symbol
load_benchmarks(trial_dir, s::Symbol) = load_benchmarks(trial_dir, Val(s))

# Load the latest benchmarking results
load_benchmarks(trial_dir::AbstractString, ::Val{:latest}) =
    load_benchmarks(argmax(mtime, list_benchmarks(trial_dir)))

# Loads the oldest benchmarking results
load_benchmarks(trial_dir::AbstractString, ::Val{:oldest}) =
    load_benchmarks(argmin(mtime, list_benchmarks(trial_dir)))

function list_benchmarks(dir)
    isdir(dir) || return String[]
    files = readdir(dir; join=true, sort=false)
    r = filter(f -> any(e -> endswith(f, e), PKG_JOGGER_EXT), files)
    @assert !isempty(r) "No benchmarking results found in $dir"
    return r
end

