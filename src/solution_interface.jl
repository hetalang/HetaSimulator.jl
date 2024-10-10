############################ Accessing Solution Values #####################

observables(sr::SimResult) = observables(sr.sim)
observables(sim::Simulation) = collect(keys(sim.vals.u[1]))
observables(sim::MCResult) = observables(sim[1])
#parameters(sim::SimResult) = sim.scenario.prob.p

@inline Base.getindex(sim::Simulation, I...) = Base.getindex(sim.vals, :, I...)
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

function DataFrame(s::Simulation; vars=observables(s), parameters_output::Vector{Symbol}=Symbol[], iter::Union{Int,Nothing}=nothing)
  df = DataFrame(t=s.vals.t)
  !isnothing(iter) && (df[!,:iter].=iter)
  length(parameters_output) > 0 && ([df[:, id] .= parameters(s)[id] for id in parameters_output])

  [df[!, v] = s[v,:] for v in vars[in.(vars, Ref(observables(s)))]]
  !isnothing(s.scope) && (df[:,:scope]=s.scope)
  
  return df
end

"""
    DataFrame(s::Simulation; 
      vars=observables(s), parameters_output::Vector{Symbol}=Symbol[], iter::Union{Int,Nothing}=nothing)

Converts simulation results of type `SimResult`, `MCResult`, etc  to `DataFrame`.

Example: `DataFrame(s)`

Arguments:

- `s` : simulation results of type [`SimResult`](@ref), [`MCResult`](@ref) or `Vector` containing them
- `parameters_output` : parameters provided as kwarg `parameters` to `sim` or `mc` functions, which should be included in `DataFrame`. Default is `empty`
- `iter` : `Int` iteration id, which should be included in `DataFrame`. Default is `nothing`
"""
function DataFrame(sr::SimResult; kwargs...)
  df = DataFrame(sr.sim; kwargs...)

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
  df = DataFrame(res[1]; kwargs...)
  lres = length(res)
  if lres > 1 
    for i in 2:lres
      append!(df, DataFrame(res[i]; kwargs...), cols=:union)
    end
  end
  return df
end

function DataFrame(mcr::MCResult; itercol=true, kwargs...)
  # df performance
  df = DataFrame(mcr[1]; iter=(itercol ? 1 : nothing), kwargs...)
  lmcr = length(mcr)

  if lmcr > 1
    for i in 2:lmcr
      append!(df, DataFrame(mcr[i]; iter=(itercol ? i : nothing), kwargs...))
    end
  end
  return df
end

function DataFrame(mcr::Pair{Symbol,S}; kwargs...) where S<:MCResult
  df = DataFrame(last(mcr); kwargs...)
  df[!, :scenario] .= first(mcr) # add new column

  return df
end

function DataFrame(res::Vector{Pair{Symbol,S}}; kwargs...) where S<:MCResult
  df = DataFrame(res[1]; kwargs...)
  lres = length(res)
  if lres > 1 
    for i in 2:lres
      append!(df, DataFrame(res[i]; kwargs...), cols=:union)
    end
  end
  return df
end
