using BenchmarkTools
using Example

suite = BenchmarkGroup()

suite["1ms"] = @benchmarkable Example.sleep_mill()
suite["2ms"] = @benchmarkable Example.sleep_two_mill()
