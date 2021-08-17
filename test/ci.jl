using Test
using PkgJogger
using Glob

include("utils.jl")

function run_ci_workflow(pkg_dir)
    # Create temporary default project
    mktempdir() do temp_project
        # Get a temporary version of PkgJogger
        temp_version = create_temp_version()

        # Construct CI Command
        cmd = Cmd([
            "julia", "--code-coverage=all", "--eval",
            "using Pkg; Pkg.develop(path=\"$temp_version\"); using PkgJogger; PkgJogger.ci()"
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
        @info cmd

        # Run workflow and return output
        proc = run(cmd)
        if proc.exitcode != 0
            @info read(cmd_stdout, String)
            @info read(cmd_stderr, String)
            error("$cmd exited with $proc.exitcode")
        end

        # Copy back *.cov files so coverage counts are correct
        for covfile in glob("**/*.cov", temp_version)
            dst = joinpath(PKG_JOGGER_PATH, relpath(covfile, temp_version))
            @info covfile, dst
            cp(covfile, dst)
        end

        return proc, cmd_stdout, cmd_stderr
    end
end

@testset "PkgJogger.jl" begin
    temp_project = create_temp_version()
    proc, cmd_stdout, cmd_stderr = run_ci_workflow(temp_project)

    # Check if benchmark results were saved
    logs = read(cmd_stderr, String)
    m = match(r"Saved benchmarks to (.*)\n", logs)
    m !== nothing || @info logs
    @test m !== nothing

    @test length(m.captures) == 1
    results_file = m.captures[1]
    @test isfile(results_file)

    # Check that results file is valid
    results = PkgJogger.load_benchmarks(results_file)
    test_loaded_results(results)
end
