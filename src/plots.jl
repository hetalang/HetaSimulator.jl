function layout_choice(n)
  return (n,1)
end

@recipe function plot(sim::Simulation; vars = observables(sim))
  @assert !isempty(vals(sim)) "Results don't contain output. You should probably add output observables to your model"

  time = times(sim)
  simvals = [sim[id,:] for id in vars]
 
  xguide --> "time"
  yguide --> "output"
  label --> permutedims(string.(vars))
  xlims --> (time[1],time[end])
  linewidth --> 3
  (time, simvals)
end


@recipe function plot(sr::SimResults; vars=observables(sr), show_measurements=true)

  @series begin
    sr.sim
  end

  # todo: separate plots for measurement tables
  if show_measurements && !isempty(measurements(sr))
    t_meas = NamedTuple{Tuple(vars)}([Float64[] for i in eachindex(vars)])
    vals_meas = NamedTuple{Tuple(vars)}([Float64[] for i in eachindex(vars)])
    for meas in measurements(sr)
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
          xguide --> "time"
          yguide --> "output"
          label --> "$(v)"
          (t_meas[v], vals_meas[v])
        end
      end
    end
  end
  nothing
end
#= XXX: do we need it?
@recipe function plot(sim::Vector{S}) where S <:AbstractResults
  [Symbol("_$i")=>s for (i,s) in enumerate(sim)]
end
=#
@recipe function plot(s::Pair{Symbol,S}) where S<:AbstractResults
  @series begin
    title := "$(first(s))"
    last(s)
  end
end

@recipe function plot(sim::Vector{Pair{Symbol,S}}) where S<:AbstractResults
  (m,n) = layout_choice(length(sim))
  layout := (m,n)
  size := (400*n,300*m)

  for (i, s) in enumerate(sim)
    @series begin
      subplot := i
      s
    end
  end
end

#https://github.com/SciML/SciMLBase.jl/blob/7151bbe784df70cc572073d76d3a818aa8d1f4d0/src/ensemble/ensemble_solutions.jl#L102
@recipe function plot(sol::MCResults)
  for i in 1:length(sol)
    @series begin
      legend := false
      sol[i]
    end
  end
end
