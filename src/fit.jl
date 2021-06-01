const DEFAULT_FITTING_RELTOL = 1e-6
const DEFAULT_FITTING_ABSTOL = 1e-8

### general interface

function fit(
  condition_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{Pair{Symbol,Float64}};
  alg=DEFAULT_ALG,
  reltol=DEFAULT_FITTING_RELTOL,
  abstol=DEFAULT_FITTING_ABSTOL,
  parallel_type=EnsembleSerial(),
  ftol_abs = 0.0,
  ftol_rel = 1e-4, 
  xtol_rel = 0.0,
  xtol_abs = 0.0, 
  fit_alg = :LN_NELDERMEAD,
  maxeval = 10000,
  maxtime = 0.0,
  lbounds = fill(0.0, length(params)),
  ubounds = fill(Inf, length(params)),
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
  
  selected_prob = [remake_saveat(last(cond).prob, last(cond).measurements) for cond in selected_condition_pairs]


  function prob_func(x)
    function internal_prob_func(prob,i,repeat)
      update_init_values(selected_prob[i],last(selected_condition_pairs[i]).init_func,x)
    end
  end

  function _output(sol, i)
    sol.retcode != :Success && error("Cond_ID $i returned $(sol.retcode) status")
    sim = build_results(sol,last(selected_condition_pairs[i]))
    loss_val = loss(sim, sim.cond.measurements) 
    (loss_val, false)
  end

  function _reduction(u, batch, I)
    (sum(batch),false)
  end

  prob(x) = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func(x),
    output_func = _output,
    reduction = _reduction
  )

  params_names = first.(params)

  function obj_func(x, grad)
    # try - catch is a tmp solution for NLopt 
    x_nt = NamedTuple{Tuple(params_names)}(x)
    prob_i = prob(x_nt)
    sol = try
      solve(prob_i, alg, parallel_type;
        trajectories = length(selected_condition_pairs),
        reltol,
        abstol,
        save_start = false, 
        save_end = false, 
        save_everystep = false, 
        kwargs...
    )
    catch e
        @warn "Error when calling loss_func($x): $e"
    end
    #println(x_pairs)
    return sol.u
  end

  opt = Opt(fit_alg, length(params))
  opt.min_objective = obj_func

  opt.ftol_rel = ftol_rel
  opt.ftol_abs = ftol_abs

  opt.xtol_rel = xtol_rel
  opt.xtol_abs = xtol_abs

  opt.maxeval = maxeval
  opt.maxtime = maxtime

  lower_bounds!(opt, lbounds)
  upper_bounds!(opt, ubounds)
  (minf, minx, ret) = NLopt.optimize(opt, last.(params))

  # to create pairs from Float64
  minx_pairs = [key=>value for (key, value) in zip(first.(params), minx)]
  
  return FitResults(minf, minx_pairs, ret, opt.numevals)

end

### fit many conditions

function fit(
  conditions::AbstractVector{C},
  params::Vector{Pair{Symbol,Float64}};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractCond}
  condition_pairs = Pair{Symbol,AbstractCond}[Symbol("Cond_ID$i") => cond for (i, cond) in pairs(conditions)]
  return fit(condition_pairs, params; kwargs...)
end

### fit platform

function fit(
  platform::Platform,
  params::Vector{Pair{Symbol,Float64}};
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... # other arguments to fit()
)
  if isnothing(conditions)
    condition_pairs = [platform.conditions...]
  else
    condition_pairs = Pair{Symbol,AbstractCond}[]
    for cond_name in conditions
      @assert haskey(platform.conditions, cond_name) "No condition :$cond_name found in the platform."
      push!(condition_pairs, cond_name=>platform.conditions[cond_name])
    end
  end

  return fit(condition_pairs, params; kwargs...)
end
