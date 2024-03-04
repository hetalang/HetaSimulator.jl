########################################## Statistics ######################################################
# Statistics for MCResult type
# currently median and quantile don't output LVector

function SciMLBase.EnsembleAnalysis.get_timestep(mcr::MCResult,i) 
  @assert has_saveat(mcr) "Solution doesn't contain single time vector, default statistics are not available."
  return (getindex(mcr[j],i) for j in 1:length(mcr))
end

# XXX: maybe it's a good idea to add: vars::AbstractVector{Symbol}=observables(mcr)
function SciMLBase.EnsembleAnalysis.get_timepoint(mcr::MCResult, t)
  @assert has_saveat(mcr) "Solution doesn't contain single time vector, default statistics are not available."

  # indexes = indexin(vars, observables(mcr))

  res = (mcr[j](t) for j in 1:length(mcr)) # mcr[1](t) # is a LabelledArray
  
  return res
end

function SciMLBase.EnsembleAnalysis.timepoint_median(sim::MCResult, t)
  arr = componentwise_vectors_timepoint(sim, t)
  if typeof(first(arr)) <: AbstractArray
      return reshape([median(x) for x in arr], size(sim[1][1])...)
  else
      return median(arr)
  end
end

function SciMLBase.EnsembleAnalysis.timepoint_quantile(sim::MCResult, q, t)
  arr = componentwise_vectors_timepoint(sim, t)
  if typeof(first(arr)) <: AbstractArray
      return reshape([quantile(x, q) for x in arr], size(sim[1][1])...)
  else
      return quantile(arr, q)
  end
end

function SciMLBase.EnsembleAnalysis.timestep_quantile(sim::MCResult,q,i)
  arr = componentwise_vectors_timestep(sim,i)
  if typeof(first(arr)) <: AbstractArray
    return reshape([quantile(x,q) for x in arr],size(sim[1][i])...)
  else
    return quantile(arr,q)
  end
end

function SciMLBase.EnsembleAnalysis.timestep_median(sim::MCResult,i)
  arr = componentwise_vectors_timestep(sim,i)
  if typeof(first(arr)) <: AbstractArray
    return reshape([median(x) for x in arr],size(sim[1][i])...)
  else
    return median(arr)
  end
end

function SciMLBase.EnsembleAnalysis.timeseries_steps_mean(sim::MCResult)
  DiffEqArray([timestep_mean(sim, i) for i in 1:length(sim[1])], sim[1].t)
end
function SciMLBase.EnsembleAnalysis.timeseries_steps_median(sim::MCResult)
  DiffEqArray([timestep_median(sim, i) for i in 1:length(sim[1])], sim[1].t)
end
function SciMLBase.EnsembleAnalysis.timeseries_steps_quantile(sim::MCResult, q)
  DiffEqArray([timestep_quantile(sim, q, i) for i in 1:length(sim[1])], sim[1].t)
end
function SciMLBase.EnsembleAnalysis.timeseries_steps_meanvar(sim::MCResult)
  m, v = timestep_meanvar(sim, 1)
  means = [m]
  vars = [v]
  for i in 2:length(sim[1])
      m, v = timestep_meanvar(sim, i)
      push!(means, m)
      push!(vars, v)
  end
  DiffEqArray(means, sim[1].t), DiffEqArray(vars, sim[1].t)
end
function SciMLBase.EnsembleAnalysis.timeseries_steps_meancov(sim::MCResult)
  reshape(
      [timestep_meancov(sim, i, j) for i in 1:length(sim[1])
       for j in 1:length(sim[1])],
      length(sim[1]),
      length(sim[1]))
end
function SciMLBase.EnsembleAnalysis.timeseries_steps_meancor(sim::MCResult)
  reshape(
      [timestep_meancor(sim, i, j) for i in 1:length(sim[1])
       for j in 1:length(sim[1])],
      length(sim[1]),
      length(sim[1]))
end

function SciMLBase.EnsembleAnalysis.EnsembleSummary(
  sim::MCResult,
  t=sim[1].t;
  quantiles=[0.05,0.95]
)
  m,v = timeseries_point_meanvar(sim,t)
  qlow = timeseries_point_quantile(sim,quantiles[1],t)
  qhigh = timeseries_point_quantile(sim,quantiles[2],t)
  med = timeseries_point_quantile(sim,0.5,t)

  trajectories = length(sim)

  ens = EnsembleSummary{Float64, 2, typeof(t), typeof(m), typeof(v), typeof(med), typeof(qlow), typeof(qhigh)}(t,m,v,med,qlow,qhigh,trajectories,0.0,true)
  LabelledEnsembleSummary(ens,observables(sim))
end

function SciMLBase.EnsembleAnalysis.EnsembleSummary(
  sim_pair::Pair{Symbol, MCResult},
  t=last(sim_pair)[1].t;
  quantiles=[0.05,0.95]
)
  first(sim_pair) => EnsembleSummary(last(sim_pair), t; quantiles)
end

function SciMLBase.EnsembleAnalysis.EnsembleSummary(
  sim_vector::AbstractVector{Pair{Symbol, MCResult}};
  # t=?
  quantiles=[0.05,0.95]
)
  EnsembleSummary.(sim_vector; quantiles)
end
