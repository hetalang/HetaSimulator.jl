function layout_choice(n)
  return (n,1)
end

@recipe function plot(sim::Simulation; vars = observables(sim))
  @assert !isempty(vals(sim)) "Results don't contain output. You should probably add output observables to your model"

  time = times(sim)
  simvals = [sim[id,:] for id in vars]
 
  xguide --> "time"
  yguide --> "output"
  legend --> :right
  label --> permutedims(string.(vars))
  xlims --> (time[1],time[end])
  linewidth --> 3
  (time, simvals)
end


@recipe function plot(sr::SimResult; vars=observables(sr), show_measurements=true)

  # this code should be replaced with 
  #   @series begin
  #     sr.sim
  #   end
  # when we separate plots for sim and measurements

  @assert !isempty(vals(sr)) "Results don't contain output. You should probably add output observables to your model"
  
  #color_choice = theme_palette(:auto)

  time = times(sr)
  for (i,v) in enumerate(vars) 
    @series begin
      xguide --> "time"
      yguide --> "output"
      label --> String(v)
      seriescolor --> i
      #seriescolor --> color_choice[i]
      xlims --> (time[1],time[end])
      linewidth --> 3
      (time, sr[v,:])
    end
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
    for (i,v) in enumerate(vars) 
      if !isempty(t_meas[v])
        @series begin
          seriestype --> :scatter
          xguide --> "time"
          yguide --> "output"
          label --> false
          seriescolor --> i
          #seriescolor --> color_choice[i]
          (t_meas[v], vals_meas[v])
        end
      end
    end
  end
  nothing
end

#= XXX: do we need it?
@recipe function plot(sim::Vector{S}) where S <:AbstractResult
  [Symbol("_$i")=>s for (i,s) in enumerate(sim)]
end
=#

#= XXX: maybe a specific plot is required for ensemble summary
@recipe function plot(es::EnsembleSummary; vars)

end
=#

@recipe function plot(s::Pair{Symbol,S}) where S<:Union{AbstractResult, EnsembleSummary}
  @series begin
    title := "$(first(s))"
    last(s)
  end
end

@recipe function plot(sim::Vector{Pair{Symbol,S}}) where S<:Union{AbstractResult, EnsembleSummary}
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
@recipe function plot(sol::MCResult)
  for i in 1:length(sol)
    @series begin
      legend := false
      sol[i]
    end
  end
end

#=
@recipe function plot(ens::LabelledEnsembleSummary; vars=observables(ens))
  @series begin
    trajectories := [findfirst(x->x == v, observables(ens)) for v in vars]
    ens.ens
  end
end
=#

#https://github.com/SciML/SciMLBase.jl/blob/32cae24c58f9d189a46d0068d7763a948fc5e1d7/src/ensemble/ensemble_solutions.jl#L147C1-L199C4
@recipe function f(ens::LabelledEnsembleSummary;
  vars=observables(ens), 
  error_style = :ribbon, ci_type = :quantile)

  trajectories = [findfirst(x->x == v, observables(ens)) for v in vars]
  sim = ens.ens
  if ci_type in [:SEM, :std, :variance]
      if typeof(sim.u[1]) <: AbstractArray
          u = vecarr_to_vectors(sim.u)
      else
          u = [sim.u.u]
      end

      if ci_type==:SEM 
        val = [sqrt.(sim.v[i] / sim.num_monte) .* 1.96 for i in 1:length(sim.v)] 
      elseif ci_type==:std 
        val = [sqrt.(sim.v[i]) for i in 1:length(sim.v)]
      elseif ci_type==:variance
        val = [sim.v[i] for i in 1:length(sim.v)]
      end

      if typeof(sim.u[1]) <: AbstractArray
          ci_low = vecarr_to_vectors(VectorOfArray(val))
          ci_high = ci_low
      else
          ci_low = [val]
          ci_high = ci_low
      end
  elseif ci_type == :quantile
      if typeof(sim.med[1]) <: AbstractArray
          u = vecarr_to_vectors(sim.med)
      else
          u = [sim.med.u]
      end
      if typeof(sim.u[1]) <: AbstractArray
          ci_low = u - vecarr_to_vectors(sim.qlow)
          ci_high = vecarr_to_vectors(sim.qhigh) - u
      else
          ci_low = [u[1] - sim.qlow.u]
          ci_high = [sim.qhigh.u - u[1]]
      end
  else
      error("ci_type choice not valid. Must be :variance or :quantile")
  end
  
  for i in trajectories
      @series begin
          legend --> false
          linewidth --> 3
          fillalpha --> 0.2
          if error_style == :ribbon
              ribbon --> (ci_low[i], ci_high[i])
          elseif error_style == :bars
              yerror --> (ci_low[i], ci_high[i])
          elseif error_style == :none
              nothing
          else
              error("error_style not recognized")
          end
          sim.t, u[i]
      end
  end
end