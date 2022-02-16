#=
    "high level" i.e. using Platform
=#
using HetaSimulator, Plots

################################## Model Upload ###########################################
# heta_update_dev()

platform = load_platform("$HetaSimulatorDir/cases/story_2", rm_out=false);
# platform.models
# platform.scenarios

################################## Single Simulation ######################################

model = platform.models[:nameless]

Scenario(model, (0., 200.)) |> sim |> plot

################################## load and simulate scenarios  #####################

### load scenarios from csv
scn_csv = read_scenarios("./cases/story_2/scenarios.csv")
# scn_xlsx = read_scenarios("./cases/story_2/scenarios.xlsx")
add_scenarios!(platform, scn_csv)

### sim
sim1 = sim(platform, scenarios = [:three]);
sim1 |> plot
sim_all = sim(platform);
sim_all |> plot

### Measurements
# load from csv to model
measurements = read_measurements("./cases/story_2/measurements.csv");
add_measurements!(platform, measurements)

### Fitting

# loss(sim1, measurements.dataone) # why?

fit1 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], scenarios = [:dataone])
fit2 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], scenarios = [:withdata2])
fit3 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], scenarios = [:dataone,:withdata2])
fit_all = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3])

# save_as_heta("optimal.heta", fit_all, append=false)
# save_as_heta("optimal.heta", [:k1=>0.1,:k2=>0.2,:k3=>0.3])
# save_as_heta("optimal.heta", (k1=0.1,k2=0.2,k3=0.3))
optim(fit_all)

### Monte-Carlo Simulations

mcsim1 = mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000)
plot(mcsim1)

mcsim2 = mc(platform, [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)
plot(mcsim2)

################################## Monte-Carlo Parallel #####################

using Distributed
addprocs(2)
#@everywhere push!(LOAD_PATH, "Y:/")
#@everywhere using Pkg
#@everywhere Pkg.activate("Y:/HetaSimulator.jl")
@everywhere using HetaSimulator

mcsim0 = mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 20)
mcsim1 = mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 150, parallel_type=EnsembleDistributed())
