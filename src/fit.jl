const DEFAULT_FITTING_RELTOL = 1e-6
const DEFAULT_FITTING_ABSTOL = 1e-8

### general interface

"""
    fit(scenario_pairs::AbstractVector{Pair{Symbol, C}},
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
      kwargs... 
    ) where C<:AbstractScenario

Fit parameters to experimental measurements. Returns `FitResults` type.

Example: `fit([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
- `params` : optimization parameters and their initial values
- `parameters_upd` : constants, which overwrite both `Model` and `Scenario` constants. Default is `nothing`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-6
- `abstol` : relative tolerance. Default is 1e-8
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- `ftol_abs` : absolute tolerance on function value. See `NLopt.jl` docs for details. Default is `0.0`
- `ftol_rel` : relative tolerance on function value. See `NLopt.jl` docs for details. Default is `1e-4`
- `xtol_rel` : relative tolerance on optimization parameters. See `NLopt.jl` docs for details. Default is `0.0`
- `xtol_rel` : absolute tolerance on optimization parameters. See `NLopt.jl` docs for details. Default is `0.0`
- `fit_alg` : fitting algorithm. See `NLopt.jl` docs for details. Default is `:LN_NELDERMEAD`
- `maxeval` : maximum number of function evaluations. See `NLopt.jl` docs for details. Default is `1e4`
- `maxtime` : maximum optimization time (in seconds). See `NLopt.jl` docs for details. Default is `0`
- `lbounds` : lower parameters bounds. See `NLopt.jl` docs for details. Default is `fill(0.0, length(params))`
- `ubounds` : upper parameters bounds. See `NLopt.jl` docs for details. Default is `fill(Inf, length(params))`
- `scale`   : scale of the parameters (supports `:lin, :log, :log10`) to be used during fitting. Default is `fill(:lin, length(params))`
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function fit(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{Pair{Symbol,Float64}};
  parameters_upd::Union{Nothing, Vector{P}}=nothing,
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
  scale = fill(:lin, length(params)),
  kwargs... # other arguments to sim()
) where {C<:AbstractScenario, P<:Pair}

  selected_scenario_pairs = Pair{Symbol,Scenario}[]
  for scenario_pair in scenario_pairs # iterate through scenarios names
    if isempty(last(scenario_pair).measurements)
      @warn "Scenario \":$(first(scenario_pair))\" has no measurements. It will be excluded from fitting."
    else
      push!(selected_scenario_pairs, scenario_pair)
    end
  end
  
  isempty(selected_scenario_pairs) && throw("No measurements points included in scenarios.")
  
  # update saveat and initial values
  selected_prob = []
  for scn in selected_scenario_pairs
    prob_i = remake_saveat(last(scn).prob, last(scn).measurements)
    prob_i = !isnothing(parameters_upd) ? update_init_values(prob_i, last(scn).init_func, NamedTuple(parameters_upd)) : prob_i
    push!(selected_prob, prob_i)
  end

  function prob_func(x)
    function internal_prob_func(prob,i,repeat)
      update_init_values(selected_prob[i],last(selected_scenario_pairs[i]).init_func,x)
    end
  end

  function _output(sol, i)
    sol.retcode != :Success && error("Simulated scenario $i returned $(sol.retcode) status")
    sim = build_results(sol,last(selected_scenario_pairs[i]))
    loss_val = loss(sim, sim.scenario.measurements) 
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
    x_nt = NamedTuple{Tuple(params_names)}(unscale_params.(x, scale))
    prob_i = prob(x_nt)
    sol = try
      solve(prob_i, alg, parallel_type;
        trajectories = length(selected_scenario_pairs),
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

  lower_bounds!(opt, scale_params.(lbounds, scale))
  upper_bounds!(opt, scale_params.(ubounds, scale))

  params0 = scale_params.(last.(params), scale)
  (minf, minx, ret) = NLopt.optimize(opt, params0)

  # to create pairs from Float64
  minx_pairs = [key=>value for (key, value) in zip(first.(params), unscale_params.(minx, scale))]
  
  return FitResults(minf, minx_pairs, ret, opt.numevals)

end

"""
    fit(scenario_pairs::AbstractVector{Pair{Symbol, C}},
      params_df::DataFrame;
      kwargs...
    ) where C<:AbstractScenario

Fit parameters to experimental measurements. Returns `FitResults` type.

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
- `params` : DataFrame with optimization parameters setup and their initial values
- kwargs : other solver related arguments supported by `fit(scenario_pairs::Vector{<:Pair}, params::Vector{<:Pair}`
"""
function fit(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  params_df::DataFrame;
  kwargs...
) where C<:AbstractScenario
  
  gdf = groupby(params_df, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  params = gdf[(true,)].parameterId .=> gdf[(true,)].nominalValue
  lbounds = gdf[(true,)].lowerBound
  ubounds = gdf[(true,)].upperBound
  scale = gdf[(true,)].parameterScale
  parameters_upd = haskey(gdf, (false,)) ? gdf[(false,)].parameterId .=> gdf[(false,)].nominalValue : nothing

  fit(scenario_pairs, params; parameters_upd, lbounds, ubounds, scale, kwargs...)
end

### fit many scenarios
"""
    fit(scenarios::AbstractVector{C},
      params;
      kwargs...
    ) where C<:AbstractScenario

Fit parameters to experimental measurements. Returns `FitResults` type.

Example: `fit([scn2, scn3, scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

Arguments:

- `scenarios` : vector of scenarios of type [`Scenario`](@ref)
- `params` : optimization parameters and their initial values
- kwargs : other solver related arguments supported by `fit(scenario_pairs::Vector{<:Pair}, params::Vector{<:Pair}`
"""
function fit(
  scenarios::AbstractVector{C},
  params;
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractScenario}
  scenario_pairs = Pair{Symbol,AbstractScenario}[Symbol("_$i") => scn for (i, scn) in pairs(scenarios)]
  return fit(scenario_pairs, params; kwargs...)
end

### fit platform
"""
    fit(platform::Platform,
      params;
      scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
      kwargs...
    ) where C<:AbstractScenario

Fit parameters to experimental measurements. Returns `FitResults` type.

Example: `fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3];scenarios=[:scn2,:scn3])`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `params` : optimization parameters and their initial values
- `scenarios` : vector of scenarios of type [`Scenario`](@ref) or `nothing` to fit all scenarios. Default is `nothing`
- kwargs : other solver related arguments supported by `fit(scenario_pairs::Vector{<:Pair}, params::Vector{<:Pair}`
"""
function fit(
  platform::Platform,
  params;
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... # other arguments to fit()
)
  if isnothing(scenarios)
    scenario_pairs = [platform.scenarios...]
  else
    scenario_pairs = Pair{Symbol,AbstractScenario}[]
    for scn_name in scenarios
      @assert haskey(platform.scenarios, scn_name) "No scenario :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.scenarios[scn_name])
    end
  end

  return fit(scenario_pairs, params; kwargs...)
end

function scale_params(x, scale::Symbol)
  if scale == :lin 
    return x
  elseif scale == :log
    return log(x)
  elseif scale == :log10
    return log10(x)
  else
    throw("Scale \"$scale\" is not supported.")
  end
end

function unscale_params(x, scale::Symbol)
  if scale == :lin 
    return x
  elseif scale == :log
    return exp(x)
  elseif scale == :log10
    return exp10(x)
  else
    throw("Scale \"$scale\" is not supported.")
  end
end