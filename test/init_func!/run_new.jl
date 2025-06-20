using HetaSimulator, BenchmarkTools

### model upload

platform = load_jlplatform("$HetaSimulatorDir/test/init_func!/model_init_new.jl");

### load scenarios from csv

scn_csv = read_scenarios("$HetaSimulatorDir/test/init_func!/scenarios.csv")
add_scenarios!(platform, scn_csv)

### Monte-Carlo Simulations

@btime mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 10000)
# 3.694 s (19072432 allocations: 1.02 GiB)