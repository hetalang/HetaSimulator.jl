############################ Accessing Solution Values #####################

observables(sim::SimResults) = collect(keys(sim.vals[1]))
observables(sim::MCResults) = collect(keys(sim.vals[1][1]))
constants(sim::SimResults) = sim.constants

@inline Base.firstindex(S::SimResults) = firstindex(S.vals)
@inline Base.lastindex(S::SimResults) = lastindex(S.vals)

@inline Base.length(S::AbstractResults) = length(S.vals)
@inline Base.eachindex(S::SimResults) = Base.OneTo(length(S.vals))
@inline Base.IteratorSize(S::SimResults) = Base.HasLength()


Base.@propagate_inbounds Base.getindex(S::SimResults, I::Int) = S.vals[I]
Base.@propagate_inbounds Base.getindex(S::SimResults, I::Colon) = S.vals[I]
Base.@propagate_inbounds Base.getindex(S::SimResults, I::AbstractArray{Int}) = S.vals[I]
Base.@propagate_inbounds Base.getindex(S::SimResults, i::Int,::Colon) = [S.vals[j][i] for j in 1:length(S.vals)]
Base.@propagate_inbounds Base.getindex(S::SimResults, i::Symbol,::Colon) = [S.vals[j][i] for j in 1:length(S.vals)]

@inline Base.getindex(S::MCResults, I::Int) = as_simulation(S,I)

as_simulation(mc::MCResults, i;title=nothing) = SimResults(title,LVector(),mc.t,mc.vals[i],Symbol[],mc.condition)

function sol_atvalue(sol::SimResults, idx, t, scope)
  if scope == :ode_ || scope == :start_
      _id = findfirst(x->x==t, sol.t) # change to searchsortedfirst ?
  else
      t_id = findall(x->x==t, sol.t)
      _id = t_id[findfirst(x->x==scope, @view(sol.scope[t_id]))]
  end
  return sol[_id][idx]
end

# tmp 
function sol_atvalue(sol::SimResults, idx::Colon, t, scope)
  if scope == :ode_ || scope == :start_
      _id = findfirst(x->x==t, sol.t) # change to searchsortedfirst ?
  else
      t_id = findall(x->x==t, sol.t)
      _id = t_id[findfirst(x->x==scope, @view(sol.scope[t_id]))]
  end
  return sol[_id]
end

(sol::SimResults)(idx, t, scope=:ode_) = sol_atvalue(sol, idx, t, scope)

############################ Plots ########################################

function good_layout(n)
  n == 1 && return (1,1)
  n == 2 && return (2,1)
  n == 3 && return (3,1)
  n == 4 && return (2,2)
  n > 4  && return n
end

@recipe function plot(sol::SimResults; vars=observables(sol), measurements=true)

  @assert !isempty(sol.vals) "Results don't contain output. You should probably add output observables to your model"

  time = sol.t
  vals = [sol[id,:] for id in vars]
 
  @series begin
    title := "Condition ID:$(sol.title)"
    xguide --> "time"
    label --> permutedims(string.(vars))
    xlims --> (time[1],time[end])
    linewidth --> 3
    (time, vals)
  end

  if measurements == true && !isempty(sol.condition.measurements)
    t_meas = NamedTuple{Tuple(vars)}([Float64[] for i in eachindex(vars)])
    vals_meas = NamedTuple{Tuple(vars)}([Float64[] for i in eachindex(vars)])
    for meas in sol.condition.measurements
      μ = meas.μ 
      if isa(μ,Symbol) && μ ∈ vars 
        push!(t_meas[μ], meas.t)
        push!(vals_meas[μ], meas.val)
      end
    end
    for v in vars
      if !isempty(t_meas[v])
        @series begin
          seriestype --> :scatter
          title := "Condition ID:$(sol.title)"
          xguide --> "time"
          label --> "$(v)"
          (t_meas[v], vals_meas[v])
        end
      end
    end
  end
  nothing
end

@recipe function plot(sol::Vector{S}) where S <: SimResults
  layout := good_layout(length(sol))
  for (i, s) in enumerate(sol)
    if isempty(s.vals) 
      @warn "Results don't contain output. You should probably add output observables to your model"
      break
    end
    @series begin
      subplot := i
      s
    end
  end
end

#https://github.com/SciML/SciMLBase.jl/blob/7151bbe784df70cc572073d76d3a818aa8d1f4d0/src/ensemble/ensemble_solutions.jl#L102
@recipe function plot(sol::MCResults)
  for i in 1:length(sol)
    sim = as_simulation(sol,i;title=sol.title)
    @series begin
      legend := false
      sim
    end
  end
  #=
    time = sol.t
    for i in eachindex(sol.vals)
      size(sol.vals[i], 1) == 0 && continue
      @series begin
        title := "Condition ID:$(sol.title)"
        legend := false
        vals = [[si[j] for si in sol.vals[i]] for j in 1:length(sol.vals[i][1])]
        #xlims --> (time[1],time[end])
        (time, vals)
      end
    end
    =#
end

@recipe function plot(sol::Vector{S}) where S <: MCResults
  layout := good_layout(length(sol))
  for (i, s) in enumerate(sol)
    if isempty(s.vals) 
      @warn "Results don't contain output. You should probably add output observables to your model"
      break
    end
    @series begin
      subplot := i
      s
    end
  end
end

############################ DataFrames ########################################

function DataFrames.DataFrame(sol::SimResults)
  # df performance
  df = DataFrame(
    t = sol.t
  )
  labels = keys(sol.vals[1])
  for (i,v) in enumerate(labels)
      df[!, v] = sol[i,:]
  end
  df[!,:scope]=sol.scope
  return df
end
