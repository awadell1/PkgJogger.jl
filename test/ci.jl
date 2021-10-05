using Test
using PkgJogger
using Glob

include("utils.jl")

function run_ci_workflow(pkg_dir)
    # Create temporary default project
    mktempdir() do temp_project

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
        cmd = Cmd(cmd; dir=pkg_dir)
        cmd = pipeline(cmd; stdout=cmd_stdout, stderr=cmd_stderr)

        # Run workflow and return output
        proc = run(cmd)
        if proc.exitcode != 0
            @info read(cmd_stdout, String)
            @info read(cmd_stderr, String)
            error("$cmd exited with $proc.exitcode")
        end

        return proc, cmd_stdout, cmd_stderr
    end
end

function test_ci_output(proc, cmd_stdout, cmd_stderr)
    # Check if benchmark results were saved
    logs = read(cmd_stderr, String)
    m = match(r"Saved benchmarks to (.*)\n", logs)
    m !== nothing || print(logs)
    @test m !== nothing

    @test length(m.captures) == 1
    results_file = m.captures[1]
    @test isfile(results_file)

    # Check that results file is valid
    results = PkgJogger.load_benchmarks(results_file)
    test_loaded_results(results)
    results_file
end

@testset "PkgJogger.jl" begin
    proc, cmd_stdout, cmd_stderr = run_ci_workflow(PKG_JOGGER_PATH)
    results_file = test_ci_output(proc, cmd_stdout, cmd_stderr)
    @test all( ("benchmark", "trial") .== splitpath(results_file)[end-2:end-1] )
end

@testset "Unregistered Package" begin
    project = joinpath(@__DIR__, "Example.jl")
    proc, cmd_stdout, cmd_stderr = run_ci_workflow(project)
    results_file = test_ci_output(proc, cmd_stdout, cmd_stderr)
    trial_dir = joinpath(PkgJogger.benchmark_dir(project), "trial")
    test_subfile(trial_dir, results_file)
end
