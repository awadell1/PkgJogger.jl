using BenchmarkTools

suite = BenchmarkGroup()
suite["sin"] = @benchmarkable sin(rand())
suite["sincos"] = @benchmarkable sincos(rand())
