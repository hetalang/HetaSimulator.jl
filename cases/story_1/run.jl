using HetaSimulator, Plots
using DataFrames, CSV

################################## Model Upload ###########################################

platform = load_platform("$HetaSimulatorDir/cases/story_1", rm_out=false);
model = platform.models[:nameless]
# model.constants
# platform.models
# platform.conditions

################################## Single Simulation ######################################

sim(model; tspan = (0., 200.)) |> plot #1
sim(model; tspan = (0., 200.), constants = [:k1=>0.01]) |> plot #2
sim(model; saveat = 0:10:100) |> plot
sim(model; saveat = 0:10:100, tspan = (0., 50.)) |> plot
sim(model; saveat = 0:10:100, tspan = (0., 500.)) |> plot
sim(model; tspan = (0., 500.)) |> plot

################################## "low level" i.e. without Platform  #####################

### single condition sim()
cond1 = Cond(model; tspan = (0., 200.),saveat = [0.0, 50., 150., 250.]);
sim(cond1) |> plot
cond2 = Cond(model; tspan = (0., 200.), constants = [:k2 => 0.001, :k3 => 0.02]);
sim(cond2) |> plot
cond3 = Cond(model; tspan = (0., 200.), constants = [:k1=>0.01], saveat = [50., 150., 250.]);
sim(cond3) |> plot # forcely extends simulation to 250.

### sim sequentially
sim.([cond1, cond2, cond3]) |> plot
### sim together
sim([cond1, cond2, cond3]) |> plot
sim([:x => cond1, :y=>cond2, :z=>cond3]) |> plot

### load measurements from CSV
measurements_csv = read_measurements_csv("./cases/story_1/measurements.csv")
cond4 = Cond(model; constants = [:k2=>0.001, :k3=>0.04], saveat = [0.0, 50., 150., 250.]);
add_measurements!(cond4, measurements_csv; subset = Dict(:condition => :dataone)) # from CSV

### load measurements from DataFrame
measurements_df = measurements_csv |> DataFrame
add_measurements!(cond1, measurements_df; subset = Dict(:condition => :withdata2)) # from DataFrame
# cond1.measurements

### fit many conditions
res1 = fit([:x=>cond2, :y=>cond3, :z=>cond4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
res2 = fit([cond2, cond3, cond4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])

# sim whole platform
push!(platform.conditions, :one => cond1)
push!(platform.conditions, :two => cond2)
sol = sim(platform);
sol |> plot
# plot selected observables
plot(sol; vars=[:a,:c])
# plot selected observables without data
plot(sol; vars=[:a,:c], measurements=false)
# sim conditions by name
sim2 = sim(platform, conditions = [:two])
sim2 |> plot
sim1 = sim(platform, conditions = [:one])
sim1 |> plot
sim0 = sim(platform, conditions = Symbol[]) # should return empty results
sim0 |> plot

################################## "high level" i.e. using Platform  #####################

### load conditions from csv
conditions_csv = read_conditions_csv("./cases/story_1/conditions.csv")
add_conditions!(platform, conditions_csv)

### sim
sim1 = sim(platform, conditions = [:three]);
sim1 |> plot
sim_all = sim(platform);
sim_all |> plot

### Measurements
# load from csv to model
measurements = read_measurements_csv("./cases/story_1/measurements.csv");
add_measurements!(platform, measurements)

### Fitting

# loss(sim1, measurements.dataone) # why?

fit1 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], conditions = [:dataone])
fit2 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], conditions = [:withdata2])
fit3 = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3], conditions = [:dataone,:withdata2])
fit_all = fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3])

################################## Monte-Carlo Simulations  #####################

mccond1 = Cond(model; tspan = (0., 200.), constants = [:k1=>0.01], saveat = [50., 80., 150.]);
mccond2 = Cond(model; tspan = (0., 200.), constants = [:k1=>0.02], saveat = [50., 100., 200.]);
mccond3 = Cond(model; tspan = (0., 200.), constants = [:k1=>0.03], saveat = [50., 100., 180.]);

# single MC Simulation
mcsim1 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000)
plot(mcsim1)

# multi MC Simulation
mcsim2 = mc([:mc1=>mccond1,:mc2=>mccond2,:mc3=>mccond3], [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)
plot(mcsim2)

# QPlatform MC Simulation
conditions_csv = read_conditions_csv("$HetaSimulatorDir/cases/story_1/conditions.csv")
add_conditions!(platform, conditions_csv)

mcsim = mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000; conditions=[:dataone, :withdata2])
plot(mcsim)

################################## Monte-Carlo Statistics  #####################

# mean
timestep_mean(mcsim1,2)
timepoint_mean(mcsim1,80)

# median
timestep_median(mcsim1,2)
timepoint_median(mcsim1,80)

# meanvar
timestep_meanvar(mcsim1,2)
timepoint_meanvar(mcsim1,80)

# meancov
timestep_meancov(mcsim1,2,3)
timepoint_meancov(mcsim1,80.,150.)

# meancor
timestep_meancor(mcsim1,2,3)
timepoint_meancor(mcsim1,80.,150.)

# !!!quantile
timestep_quantile(mcsim1,0.95,2)
timepoint_quantile(mcsim1,0.95,80.)

# full time steps statistics
timeseries_steps_mean(mcsim1) # Computes the mean at each time step
timeseries_steps_median(mcsim1) # Computes the median at each time step
timeseries_steps_quantile(mcsim1,0.95) # Computes the quantile q at each time step
timeseries_steps_meanvar(mcsim1) # Computes the mean and variance at each time step
timeseries_steps_meancov(mcsim1) # Computes the covariance matrix and means at each time step
timeseries_steps_meancor(mcsim1) # Computes the correlation matrix and means at each time step

# Ensemble Summary
ens = EnsembleSummary(mcsim1;quantiles=[0.05,0.95])
plot(ens)

################################## Monte-Carlo Parallel #####################

using Distributed
addprocs(2)
@everywhere using HetaSimulator

mccond1 = Cond(model; tspan = (0., 200.), constants = [:k1=>0.01], saveat = [50., 80., 150.]);
mcsim0 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 20)
mcsim1 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 40, parallel_type=EnsembleDistributed())