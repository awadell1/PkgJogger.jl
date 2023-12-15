@testitem "ci" setup=[ExamplePkg] begin
    pkgjogger_env = Base.active_project()
    jogger, cleanup = ExamplePkg.create_jogger()
    dir = abspath(joinpath(jogger.BENCHMARK_DIR, ".."))
    env = copy(ENV)
    env["JULIA_LOAD_PATH"] = join(["@", "@stdlib", pkgjogger_env], Sys.iswindows() ? ";" : ":")
    cmd = Cmd(`$(Base.julia_cmd()) --startup-file=no -e 'using PkgJogger; PkgJogger.ci()'`; env, dir)
    p = run(cmd; wait=true)
    @test success(p)
    cleanup()
end
