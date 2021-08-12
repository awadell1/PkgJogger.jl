using Test
using PkgJogger

include("utils.jl")

@testset "CI workflow" begin
    # Setup CI Workflow Cmd
    path = joinpath(pathof(PkgJogger), "..", "..") |> abspath
    @info path
    cmd = Cmd(["julia", "-e", "@info pwd(); using PkgJogger; PkgJogger.ci()"]);
    cmd = ignorestatus(cmd)
    cmd = setenv(cmd,
        "JULIA_PROJECT" => path,            # Don't use the test environment
        "JULIA_LOAD_PATH" => "@:@stdlib",   # Enable stdlib but ignore user projects
        "PATH" => Sys.BINDIR                # Add Julia to the PATH
    )

    # Capture stdout and stderror
    cmd_stdout =  IOBuffer(;append=true)
    logging = IOBuffer(;append=true)
    cmd = Cmd(cmd; dir=path)
    cmd = pipeline(cmd; stdout=cmd_stdout, stderr=logging)

    # Run workflow, logging output on
    proc = run(cmd)
    if proc.exitcode != 0
        @info read(cmd_stdout, String)
        @info read(logging, String)
    end
    @test proc.exitcode == 0

    # Check if benchmark results were saved
    logs = read(logging, String)
    m = match(r"Saved benchmarks to (.*)\n", logs)
    @test length(m.captures) == 1
    results_file = m.captures[1]
    @test isfile(results_file)

    # Check that results file is valid
    results = PkgJogger.load_benchmarks(results_file)
    test_loaded_results(results)
end
