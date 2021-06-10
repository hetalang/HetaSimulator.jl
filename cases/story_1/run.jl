#=
    "low level" i.e. without Platform
=#
using HetaSimulator, Plots

################################## Model Upload ###########################################
# heta_update_dev()

platform = load_platform("$HetaSimulatorDir/cases/story_1", rm_out = false);
model = platform.models[:nameless];
# parameters(model) # def_parameters
# events_active(model) # def_events_active
# events_save(model) # def_events_save
# observables(model) # def_observations

################################## Single Simulation ######################################

sim(model; tspan = (0., 200.)) |> plot
sim(model; tspan = (0., 200.), parameters = [:k1=>0.01]) |> plot
sim(model; saveat = 0:10:100) |> plot
sim(model; saveat = 0:10:100, tspan = (0., 50.)) |> plot
sim(model; saveat = 0:10:100, tspan = (0., 500.)) |> plot
sim(
    model; 
    tspan = (0., 500.),
    events_active=[:sw1=>false, :ss1 => false],
    events_save=[:sw1=>(true,true), :ss1=>(true,true)]
    ) |> plot
sim(
    model;
    tspan = (0., 500.),
    events_active=[:sw1=>false],
    events_save=[:sw1=>(true,true)]
    ) |> plot
sim(
    model;
    tspan = (0., 500.),
    events_active=[:sw1=>true],
    events_save=[:sw1=>(false,false)]
    ) |> plot


### single condition sim()
cond1 = Cond(model; tspan = (0., 200.), saveat = [0.0, 150., 250.]);
sim(cond1) |> plot
sim(cond1; parameters_upd=[:k1=>0.01]) |> plot

cond2 = Cond(
    model;
    tspan = (0., 200.),
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.001, :k3 => 0.02]
    );
sim(cond2) |> plot

cond3 = Cond(
    model;
    tspan = (0., 250.),
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.1]
    );
sim(cond3) |> plot

### sim sequentially
sim.([cond1, cond2, cond3]) |> plot
### sim together
sim([cond1, cond2, cond3]) |> plot
sim([:x => cond1, :y=>cond2, :z=>cond3]) |> plot
sim([:x => cond1, :y=>cond2, :z=>cond3]; parameters_upd=[:k1=>0.01]) |> plot

### load measurements from CSV
measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.csv")
measurements_xlsx = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.xlsx")
cond4 = Cond(model; parameters = [:k2=>0.001, :k3=>0.04], saveat = [0.0, 50., 150., 250.]);
add_measurements!(cond4, measurements_csv; subset = [:condition => :dataone])

### fit many conditions
res1 = fit([:x=>cond2, :y=>cond3, :z=>cond4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
res2 = fit([cond2, cond3, cond4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
sim(cond3, parameters_upd = optim(res2))

# sim all conditions
sol = sim([:c1 => cond1, :c2=>cond2, :c3=>cond3, :c4=>cond4]);
plot(sol) # wrong plot

# plot selected observables
plot(sol; vars=[:a,:c])
# plot selected observables without data
plot(sol; vars=[:a,:c], measurements=false)

################################## Monte-Carlo Simulations  #####################

mccond1 = Cond(
    model;
    tspan = (0., 200.),
    parameters = [:k1=>0.01],
    saveat = [50., 80., 150.]
    );
mccond2 = Cond(
    model;
    tspan = (0., 200.),
    parameters = [:k1=>0.02],
    saveat = [50., 100., 200.]
    );
mccond3 = Cond(
    model; 
    tspan = (0., 200.),
    parameters = [:k1=>0.03],
    saveat = [50., 100., 180.],
    events_active=[:sw1 => false]
    );

# single MC Simulation
mcsim1 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000)
plot(mcsim1)

# multi MC Simulation
mcsim2 = mc(
    [:mc1=>mccond1,:mc2=>mccond2,:mc3=>mccond3],
    [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
    1000
    )
plot(mcsim2)

################################## Monte-Carlo Statistics  #####################
#= FIXME
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

mccond1 = Cond(model; tspan = (0., 200.), parameters = [:k1=>0.01], saveat = [50., 80., 150.]);
mcsim0 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 20)
mcsim1 = mc(mccond1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 150, parallel_type=EnsembleDistributed())
=#
