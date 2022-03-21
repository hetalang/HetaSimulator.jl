############################ Accessing Solution Values #####################

observables(sr::SimResult) = observables(sr.sim)
observables(sim::Simulation) = collect(keys(sim.vals.u[1]))
observables(sim::MCResult) = observables(sim[1])
constants(sim::SimResult) = sim.scenario.prob.p.constants

@inline Base.getindex(sim::Simulation, I...) = sim.vals[I...]
@inline Base.getindex(sim::Simulation, i::Symbol,::Colon) = [sim.vals[j][i] for j in 1:length(sim.vals)]
@inline Base.getindex(sr::SimResult, I...) = sr.sim[I...]
@inline Base.getindex(mc::MCResult, I...) = mc.sim[I...]

solat(sr::SimResult, args...) = solat(sr.sim, args...)

solat(sim::Simulation, t, idx, scope) = solat(sim, t, scope)[idx]
solat(sim::Simulation, t, idx::Colon, scope) = solat(sim, t, scope)

function solat(sim::Simulation, t, scope)
  if scope == :ode_ || scope == :start_
      _id = findfirst(x->x==t, sim.vals.t) # change to searchsortedfirst ?
  else
      t_id = findall(x->x==t, sim.vals.t)
      _id = t_id[findfirst(x->x==scope, @view(sim.scope[t_id]))]
  end
  return sim[_id]
end

(s::Simulation)(t, idx=:, scope=:ode_) = solat(s, t, idx, scope)
(sr::SimResult)(t, idx=:, scope=:ode_) = solat(sr.sim, t, idx, scope)

############################ DataFrames ########################################

function DataFrame(s::Simulation; vars=observables(s), kwargs...)
  df = DataFrame(t=s.vals.t, kwargs...)

  [df[!, v] = s[v,:] for v in vars[in.(vars, Ref(observables(s)))]]
  !isnothing(s.scope) && (df[!,:scope]=s.scope)
  
  return df
end

function DataFrame(sr::SimResult; vars=observables(sr.sim), add_parameters=false, kwargs...)
  df = DataFrame(sr.sim; vars, kwargs...)

  if add_parameters
    parameters_la = parameters(sr.scenario)
    parameters_names = keys(parameters_la)
    
    for i in 1:length(parameters_la)
      df[:,parameters_names[i]] .= parameters_la[i]
    end
  end

  # XXX: experimental option, currently group column is more useful
  if length(sr.scenario.tags) > 0
    for tag in sr.scenario.tags
      df[:,"tags.$tag"] .= true
    end
  end

  # group column
  if !isnothing(sr.scenario.group)
    df.group .= sr.scenario.group
  end

  return df
end

function DataFrame(sr::Pair{Symbol,S}; kwargs...) where S<:SimResult
  df = DataFrame(last(sr); kwargs...)
  df[!, :scenario] .= first(sr) # add new column

  return df
end

function DataFrame(res::Vector{Pair{Symbol,S}}; kwargs...) where S<:SimResult
  df_vectors = DataFrame.(res; kwargs...)

  return vcat(df_vectors...; cols=:union)
end

function DataFrame(mcr::MCResult; kwargs...)
  # df performance
  df = DataFrame()

  for (i,s) in enumerate(mcr.sim)
      dfs = DataFrame(s; kwargs...)
      insertcols!(dfs, 1, :iter => fill(i, length(s)))
      df = vcat(df,dfs)
  end
  
  return df
end

function DataFrame(mcr::Pair{Symbol,S}; kwargs...) where S<:MCResult
  df = DataFrame(last(mcr); kwargs...)
  df[!, :scenario] .= first(mcr) # add new column

  return df
end

function DataFrame(res::Vector{Pair{Symbol,S}}; kwargs...) where S<:MCResult
  df_vectors = DataFrame.(res; kwargs...)

  return vcat(df_vectors...; cols=:union)
end

############################ Save Result ########################################
"""
    save_results(filepath::String, sim::AbstractResult) 

Save results as csv file

Arguments:

- `filepath`: path and name of the file to write to
- `sim`: simulation results of `AbstractResult` type
"""
save_results(filepath::String, sim::AbstractResult) = save_results(filepath, DataFrame(sim))

save_results(filepath::String, df::DataFrame) = CSV.write(filepath, df, delim=";")

#=FIXME
function save_results(path::String, mcsim::MCResult; groupby::Symbol=:observables) 
  if groupby == :simulations
    for i in 1:length(mcsim)
      save_results("$path/$i.csv", mcsim[i])
    end
  elseif groupby == :observables
    obs = observables(mcsim[1])
    lobs = length(obs)
    for ob in obs
      df = DataFrame(t = mcsim[1].t)
      [df[!,string(i)] = mcsim[i][ob,:] for i in 1:length(mcsim)]
      CSV.write("$path/$ob.csv", df, delim=";")
    end
  end
end
=#