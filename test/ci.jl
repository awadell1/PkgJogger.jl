using Test
using PkgJogger

include("utils.jl")

function run_ci_workflow(pkg_dir)
    # Create temporary default project
    mktempdir() do temp_project
        # Copy pkg_dir to temp_project, and fix permissions
        cp(pkg_dir, temp_project; force=true)
        chmod(temp_project, 0o700; recursive=true)

        # Construct CI Command
        pkgjogger_path = escape_string(PKG_JOGGER_PATH)
        cli_script = """
            using Pkg
            Pkg.activate(temp=true)
            Pkg.develop(path=\"$pkgjogger_path\")
            using PkgJogger
            PkgJogger.ci()
        """
        cmd = ignorestatus(Cmd(Vector{String}(filter(!isnothing, [
            joinpath(Sys.BINDIR, "julia"),
            "--startup-file=no",
            Base.JLOptions().code_coverage > 0 ? "--code-coverage=all" : nothing,
            "--eval",
            cli_script,
        ]))))

        # Enable user project + stdlib but remove additional entries from JULIA_LOAD_PATH
        # This replicates the behavior of `] test`
        sep = Sys.iswindows() ? ";" : ":"
        cmd = setenv(cmd, "JULIA_LOAD_PATH" => join(["@", "@stdlib"], sep))

        # Check things are setup
        @test isdir(temp_project)
        @test isdir(Sys.BINDIR)
        @test isdir(PKG_JOGGER_PATH)

       # Capture stdout and stderror
        cmd_stdout =  IOBuffer(;append=true)
        cmd_stderr = IOBuffer(;append=true)
        cmd = Cmd(cmd; dir=temp_project)
        cmd = pipeline(cmd; stdout=cmd_stdout, stderr=cmd_stderr)

        # Run workflow and return output
        proc = run(cmd)
        if proc.exitcode != 0
            @info read(cmd_stdout, String)
            @info read(cmd_stderr, String)
            error("$cmd exited with $proc.exitcode")
        end

        # Check if benchmark results were saved
        logs = read(cmd_stderr, String)
        m = match(r"Saved benchmarks to (.*)\n", logs)
        m !== nothing || print(logs)
        @test m !== nothing

        @test length(m.captures) == 1
        results_file = m.captures[1]
        @test isfile(results_file)

        # Check that results are in the right place
        trial_dir = joinpath(PkgJogger.benchmark_dir(temp_project), "trial")
        @test isfile(joinpath(trial_dir, splitpath(results_file)[end]))

        # Check that results file is valid
        results = PkgJogger.load_benchmarks(results_file)
        test_loaded_results(results)

        # Further checks
        return results
    end
end

@testset "Example.jl" begin
    project = joinpath(@__DIR__, "Example.jl")
    results = run_ci_workflow(project)
    cleanup_example()

    # Check timer results are decent (sleep isn't very accurate)
    isapprox((time???minimum)(results["benchmarks"][["bench_timer.jl", "1ms"]]), 1e6; atol=3e6)
    isapprox((time???minimum)(results["benchmarks"][["bench_timer.jl", "2ms"]]), 2e6; atol=3e6)
end
