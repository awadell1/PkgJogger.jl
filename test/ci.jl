using Test
using PkgJogger

include("utils.jl")

function run_ci_workflow(pkg_dir)
    # Create temporary default project
    mktempdir() do temp_project
        # Copy pkg_dir to temp_project
        cp(pkg_dir, temp_project; force=true)

        # Construct CI Command
        cmd = Cmd([
            "julia", "--code-coverage=all", "--eval",
            "using Pkg; Pkg.develop(path=\"$PKG_JOGGER_PATH\"); using PkgJogger; PkgJogger.ci()"
        ]) |> ignorestatus

        # Set Environmental Variables
        cmd = setenv(cmd,
            "JULIA_PROJECT" => temp_project,    # Use the temporary project
            "JULIA_LOAD_PATH" => "@:@stdlib",   # Enable stdlib but ignore user projects
            "PATH" => Sys.BINDIR,               # Add Julia to the PATH
        )

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
        test_subfile(temp_project, results_file)
        trial_dir = joinpath(PkgJogger.benchmark_dir(temp_project), "trial")
        test_subfile(trial_dir, results_file)

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

    # Check timer results are decent (sleep isn't very accurate)
    isapprox((time∘minimum)(results["benchmarks"][["timer", "1ms"]]), 1e6; atol=3e6)
    isapprox((time∘minimum)(results["benchmarks"][["timer", "2ms"]]), 2e6; atol=3e6)
end
