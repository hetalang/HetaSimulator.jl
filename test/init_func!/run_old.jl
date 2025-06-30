using HetaSimulator, BenchmarkTools

### model upload

platform = load_jlplatform("$HetaSimulatorDir/test/init_func!/model_init_old.jl");

### load scenarios from csv

scn_csv = read_scenarios("$HetaSimulatorDir/test/init_func!/scenarios.csv")
add_scenarios!(platform, scn_csv)

### Monte-Carlo Simulations

@btime mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 10000)
# 4.106 s (19390852 allocations: 1.03 GiB)