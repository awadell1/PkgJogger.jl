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
    sandbox(pkg, load_path) do
        @eval Main begin
            using PkgJogger
            using $pkgname
            jogger = @jog $pkgname
            result = jogger.benchmark()
        end
    end
end

function sandbox(f, pkg, load_path)
    # Save current project and load path
    current_project = Pkg.project()
    current_load_path = Base.LOAD_PATH

    # Build temporary environment
    Pkg.activate(;temp=true)
    Pkg.add(pkg; io=IOBuffer())
    Pkg.add(JOGGER_PKGS; preserve=PRESERVE_ALL, io=IOBuffer())
    Pkg.instantiate(; io=IOBuffer())

    # Update LOAD_PATH
    empty!(Base.LOAD_PATH)
    append!(Base.LOAD_PATH, vcat(["@"], load_path, ["@stdlib"]))

    # Report current status
    Pkg.status(;mode=PKGMODE_MANIFEST)
    @info "LOAD_PATH: $(Base.LOAD_PATH)"

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
