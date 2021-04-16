const DEFAULT_ESTIMATION_RELTOL = 1e-8
const DEFAULT_ESTIMATION_ABSTOL = 1e-12

### general interface

function fit(
  condition_pairs::AbstractVector{Pair{Symbol, C}},
  param::Vector{Pair{Symbol,Float64}};
  ftol_abs = 0.0,
  ftol_rel = 1e-4, 
  xtol_rel = 0.0,
  xtol_abs = 0.0, 
  fit_alg = :LN_NELDERMEAD,
  maxeval = 10000,
  maxtime = 0.0,
  lbounds = fill(0.0, length(param)),
  ubounds = fill(Inf, length(param)),
  kwargs... # other arguments to sim()
) where C<:AbstractCond

  selected_condition_pairs = Pair{Symbol,Cond}[]
  for cond_pair in condition_pairs # iterate through condition names
    if isempty(last(cond_pair).measurements)
      @warn "Cond \":$(first(cond_pair))\" has no measurements. It will be excluded from fitting."
    else
      push!(selected_condition_pairs, cond_pair)
    end
  end
  
  isempty(selected_condition_pairs) && throw("No measurements points included in conditions.")

  function _output(sol, i)
    sim = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
    loss_val = loss(sim, last(selected_condition_pairs[i]).measurements) 
    (loss_val, false)
  end

  function _reduction(u, batch, I)
    (sum(batch),false)
  end

  function obj_func(x, grad)
    # try - catch is a tmp solution for NLopt 
    x_pairs = [key=>value for (key, value) in zip(first.(param), x)]
    sol = try
        sim(
          selected_condition_pairs;
          constants = x_pairs,
          output_func = _output,
          reduction = _reduction,
          saveat_measurements = true,
          kwargs...
        )
    catch e
        @warn "Error when calling loss_func($x)"
        throw(e)
    end
    #println(x_pairs)
    #println(sim)
    return sol
  end

  opt = Opt(fit_alg, length(param))
  opt.min_objective = obj_func

  opt.ftol_rel = ftol_rel
  opt.ftol_abs = ftol_abs

  opt.xtol_rel = xtol_rel
  opt.xtol_abs = xtol_abs

  opt.maxeval = maxeval
  opt.maxtime = maxtime

  lower_bounds!(opt, lbounds)
  upper_bounds!(opt, ubounds)
  (minf, minx, ret) = NLopt.optimize(opt, last.(param))

  # to create pairs from Float64
  minx_pairs = [key=>value for (key, value) in zip(first.(param), minx)]
  
  return FitResults(minf, minx_pairs, ret)
end

### fit many conditions

function fit(
  conditions::AbstractVector{C},
  param::Vector{Pair{Symbol,Float64}};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractCond}
  condition_pairs = Pair{Symbol,AbstractCond}[Symbol("#$i") => cond for (i, cond) in pairs(conditions)]
  return fit(condition_pairs, param; kwargs...)
end

### fit platform

function fit(
  platform::QPlatform,
  param::Vector{Pair{Symbol,Float64}};
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... # other arguments to fit()
)
  if conditions === nothing
    condition_pairs = [platform.conditions...]
  else
    condition_pairs = Pair{Symbol,AbstractCond}[]
    for cond_name in conditions
      @assert haskey(platform.conditions, cond_name) "No condition :$cond_name found in the platform."
      push!(condition_pairs, cond_name=>platform.conditions[cond_name])
    end
  end

  return fit(condition_pairs, param; kwargs...)
end
