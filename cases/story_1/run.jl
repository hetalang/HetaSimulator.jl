#=
    "low level" way i.e. without Platform
    Scenario constructor, loading measurements from file
    `sim` for single scenario, scenario array, pairs array
    `fit` for scenario array, pairs array
    `mc` for single scenario, scenario array, pairs array
    statistics
=#
using HetaSimulator, Plots

################################## Model Upload ###########################################

platform = load_platform("$HetaSimulatorDir/cases/story_1", rm_out = false)
#platform = load_jlplatform("$HetaSimulatorDir/cases/story_1/_julia/model.jl")
model = platform.models[:nameless]
# parameters(model) # def_parameters
# events_active(model) # def_events_active
# events_save(model) # def_events_save
# observables(model) # def_observations

################################## Single Simulation ######################################
Scenario(model, (0., 200.)) |> sim |> plot
scn0 = Scenario(model, (0., 200.))
sim(scn0, parameters = [:k1=>0.01]) |> plot
sim(Scenario(model, (0,100), saveat = 0:10:100)) |> plot
sim(Scenario(model, (0., 50.), saveat = 0:10:100)) |> plot
sim(Scenario(model, (0., 500.), saveat = 0:10:100)) |> plot
Scenario( # throw error
    model, 
    (0., 500.);
    events_active=[:sw1=>false, :ss1 => false],
    events_save=[:sw1=>(true,true), :ss1=>(true,true)]
    ) |> sim |> plot
Scenario(
    model,
    (0., 500.);
    events_active=[:sw1=>false],
    events_save=[:sw1=>(true,true)]
    ) |> sim |> plot
Scenario(
    model,
    (0., 500.);
    events_active=[:sw1=>true],
    events_save=[:sw1=>(false,false)]
    ) |> sim |> plot
sim(Scenario(model, (0., 10.); parameters=[:k1=>1e-3]), parameters = [:k1=>1e-3])

### single scenario sim()
scn1 = Scenario(model, (0., 200.));
sim(scn1) |> plot
sim(scn1; parameters=[:k1=>0.01]) |> plot

scn2 = Scenario(
    model,
    (0., 200.);
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.001, :k3 => 0.02]
    );
sim(scn2) |> plot

scn3 = Scenario(
    model,
    (0., 250.);
    events_active=[:sw1=>false],
    parameters = [:k2 => 0.1]
    );
sim(scn3) |> plot

### sim sequentially 
sim.([scn1, scn2, scn3]) .|> plot
### sim together
sim([scn1, scn2, scn3]) |> plot
sim([:x => scn1, :y=>scn2, :z=>scn3]) |> plot
x=sim([:x => scn1, :y=>scn2, :z=>scn3]; parameters=[:k1=>0.1]) |> plot

### load measurements from CSV
#measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.csv")
measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements_no_scope.csv")
measurements_xlsx = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.xlsx")
scn4 = Scenario(model, (0,250); parameters = [:k2=>0.001, :k3=>0.04], saveat = [0.0, 50., 150., 250.]);
add_measurements!(scn4, measurements_csv; subset = [:scenario => :dataone])

### fit many scenarios
estim = estimator(
    [:x=>scn2, :y=>scn3, :z=>scn4],
    [:k1=>0.1,:k2=>0.2,:k3=>0.3]
)
estim([0.01, 0.02, 0.35])
res1 = fit([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
res2 = fit([scn2, scn3, scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])
sim(scn4, parameters = optim(res2)) |> plot

# sim all scenarios
sol = sim([:c1=>scn1, :c2=>scn2, :c3=>scn3, :c4=>scn4]);
plot(sol)

# plot selected observables
plot(sol; vars=[:a,:c])
# plot selected observables without data
plot(sol; vars=[:a,:c], show_measurements=false)

################################## Monte-Carlo Simulations  #####################

mc_scn1 = Scenario(
    model,
    (0., 200.);
    parameters = [:k1=>0.01],
    saveat = [50., 80., 150.]
    );

mc_scn2 = Scenario(
    model,
    (0., 200.);
    parameters = [:k1=>0.02],
    saveat = [50., 100., 200.]
    );
    
mc_scn3 = Scenario(
    model,
    (0., 200.);
    parameters = [:k1=>0.03],
    events_active=[:sw1 => false]
    );

# single MC Simulation
mcsim1 = mc(mc_scn1, [:k1=>Uniform(1e-3,1e-2), :k3=>Normal(1e-4,1e-5), :k2=>Normal(1e-3,1e-4)], 1000)
plot(mcsim1)

# multi MC Simulation
mcsim2 = mc(
    [:mc1=>mc_scn1,:mc2=>mc_scn2,:mc3=>mc_scn3],
    [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
    1000
  )
plot(mcsim2)

mcsim3 = mc(
    [mc_scn1, mc_scn2, mc_scn3],
    [:k1=>0.01, :k2=>LogNormal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
    1000
  )
plot(mcsim3)

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

plot(ens, ci_type=:SEM, title="SEM")
plot(ens, ci_type=:std, title="std")
plot(ens, ci_type=:variance, vars=[:a,:b], title="variance")
plot(ens, ci_type=:quantile, vars=[:c], title="quantile")

################################## Monte-Carlo Parallel #####################
#= 
using Distributed
addprocs(2)
@everywhere using HetaSimulator

mcscn1 = Scenario(model, (0., 200.), parameters = [:k1=>0.01], saveat = [50., 80., 150.]);
mcsim0 = mc(mcscn1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 20)
mcsim1 = mc(mcscn1, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 150, parallel_type=EnsembleDistributed())
=#
