# the code was tested on v0.4.2
# update HetaSimulator
# with ] add https://github.com/hetalang/HetaSimulator.jl

using HetaSimulator, Plots
using Distributed # to use parallel simulations

platform = load_platform(".")
model = platform.models[:nameless]

### Single scenario simulations

mcscn1 = Scenario(
  model,
  (0., 200.);
  parameters = [:k1=>0.01]
)

mcscn2 = Scenario(
  model,
  (0., 200.);
  parameters = [:k1=>0.02]
)

mcsim1 = mc(
  mcscn1,
  [:k1=>Uniform(1e-3,1e-2), :k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)],
  100,
  saveat = [50., 80., 150.]
)

plotd = plot(mcsim1, vars=[:b])
# savefig(plotd, "fig.png")

mc_df1 = DataFrame(mcsim1, vars=[:a, :b])

### Multiple scenarios simulations

mcsim2 = mc(
  [:mc1=>mcscn1,:mc2=>mcscn2],
  [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
  100,
  saveat = [50., 100., 200.]
)
plotd = plot(mcsim2)
# savefig(plotd,"file.png")

mc_df2 = DataFrame(mcsim2)

### Monte-Carlo for whole platform

scn_csv = read_scenarios("./scenarios.csv")
add_scenarios!(platform, scn_csv)

mcplat = mc(
  platform,
  [:k1=>0.01, :k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)],
  100
)
plotd = plot(mcplat)
# savefig(plotd,"file.png")

### Using pre-generated parameter set

#=
mcvecs = DataFrame(
  k1=0.01,
  k2=rand(Normal(1e-3,1e-4), 50),
  k3=rand(Uniform(1e-4,1e-2), 50)
)
=#

mcvecs = read_mcvecs("./params.csv")

mcv1 = mc(mcscn1, mcvecs)
plotd = plot(mcv1)
# savefig(plotd,"file.png")

# parallel simulations

addprocs(2)
@everywhere using HetaSimulator

mcv2 = mc(
  mcscn1,
  mcvecs;
  parallel_type=EnsembleDistributed()
)

### Monte-Carlo statistics
# see https://diffeq.sciml.ai/stable/features/ensemble/#Summary-Statistics

# mean
timestep_mean(mcv1,2)
timepoint_mean(mcv1,80)

# median
timestep_median(mcv1,2)
timepoint_median(mcv1,80)

# meanvar
timestep_meanvar(mcv1,2)
timepoint_meanvar(mcv1,80)

# meancov
timestep_meancov(mcv1,2,3)
timepoint_meancov(mcv1,80.,150.)

# meancor
timestep_meancor(mcv1,2,3)
timepoint_meancor(mcv1,80.,150.)

# !!!quantile
timestep_quantile(mcv1,0.95,2)
timepoint_quantile(mcv1,0.95,80.)

# full time steps statistics
timeseries_steps_mean(mcv1) # Computes the mean at each time step
timeseries_steps_median(mcv1) # Computes the median at each time step
timeseries_steps_quantile(mcv1,0.95) # Computes the quantile q at each time step
timeseries_steps_meanvar(mcv1) # Computes the mean and variance at each time step
timeseries_steps_meancov(mcv1) # Computes the covariance matrix and means at each time step
timeseries_steps_meancor(mcv1) # Computes the correlation matrix and means at each time step

# Ensemble Summary
ens = EnsembleSummary(mcsim1;quantiles=[0.05,0.95])
plot(ens)
# plotd = plot(ens)
# savefig(plotd,"file.png")