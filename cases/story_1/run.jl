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
sim(model; tspan = (0., 200.), parameters_upd = [:k1=>0.01]) |> plot
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


### single scenario sim()
scn1 = HetaSimulator.Condition(model; tspan = (0., 200.), saveat = [0.0, 150., 250.]);
sim(scn1) |> plot
sim(scn1; parameters_upd=[:k1=>0.01]) |> plot

scn2 = HetaSimulator.Condition(
    model;
    tspan = (0., 200.),
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.001, :k3 => 0.02]
    );
sim(scn2) |> plot

scn3 = HetaSimulator.Condition(
    model;
    tspan = (0., 250.),
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.1]
    );
sim(scn3) |> plot

### sim sequentially
sim.([scn1, scn2, scn3]) |> plot
### sim together
sim([scn1, scn2, scn3]) |> plot
sim([:x => scn1, :y=>scn2, :z=>scn3]) |> plot
sim([:x => scn1, :y=>scn2, :z=>scn3]; parameters_upd=[:k1=>0.01]) |> plot

### load measurements from CSV
#measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.csv")
measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements_no_scope.csv")
measurements_xlsx = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.xlsx")
scn4 = HetaSimulator.Condition(model; parameters = [:k2=>0.001, :k3=>0.04], saveat = [0.0, 50., 150., 250.]);
add_measurements!(scn4, measurements_csv; subset = [:condition => :dataone])

### fit many scenarios
res1 = fit([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
res2 = fit([scn2, scn3, scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
sim(scn3, parameters_upd = optim(res2))

# sim all scenarios
sol = sim([:c1=>scn1, :c2=>scn2, :c3=>scn3, :c4=>scn4]);
plot(sol) # wrong plot

# plot selected observables
plot(sol; vars=[:a,:c])
# plot selected observables without data
plot(sol; vars=[:a,:c], measurements=false)

################################## Conditions ###################################

scn_csv = read_conditions("$HetaSimulatorDir/cases/story_2/conditions_w_events.csv")
add_conditions!(platform, scn_csv)

################################## Monte-Carlo Simulations  #####################

mcscn1 = HetaSimulator.Condition(
    model;
    tspan = (0., 200.),
    parameters = [:k1=>0.01],
    saveat = [50., 80., 150.]
    );

mcscn2 = HetaSimulator.Condition(
    model;
    tspan = (0., 200.),
    parameters = [:k1=>0.02],
    saveat = [50., 100., 200.]
    );
    
mcscn3 = HetaSimulator.Condition(
    model; 
    tspan = (0., 200.),
    parameters = [:k1=>0.03],
    saveat = [50., 100., 180.],
    events_active=[:sw1 => false]
    );

# single MC Simulation
mcsim1 = mc(mcscn1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000)
plot(mcsim1)

# multi MC Simulation
mcsim2 = mc(
    [:mc1=>mcscn1,:mc2=>mcscn2,:mc3=>mcscn3],
    [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
    1000
  )
plot(mcsim2)

mcsim3 = mc(
    [mcscn1, mcscn2, mcscn3],
    [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
    1000
  )
plot(mcsim3)

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

mcscn1 = HetaSimulator.Condition(model; tspan = (0., 200.), parameters = [:k1=>0.01], saveat = [50., 80., 150.]);
mcsim0 = mc(mcscn1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 20)
mcsim1 = mc(mcscn1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 150, parallel_type=EnsembleDistributed())
=#
