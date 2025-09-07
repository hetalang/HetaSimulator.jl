const DEFAULT_FITTING_RELTOL = 1e-6
const DEFAULT_FITTING_ABSTOL = 1e-8

### general interface

"""
    fit(
      scenario_pairs::AbstractVector{Pair{Symbol, C}},
      parameters_fitted::AbstractVector{<:Pair{Symbol,<:Real}};
      parameters::Union{Nothing, Vector{P}}=nothing,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_FITTING_RELTOL,
      abstol=DEFAULT_FITTING_ABSTOL,
      parallel_type=EnsembleSerial(),
      adtype=AutoForwardDiff(),
      ftol_abs = 0.0,
      ftol_rel = 1e-4,
      fit_alg = NLopt.LN_NELDERMEAD(),
      maxiters = 10000,
      maxtime = nothing,
      lbounds = fill(0.0, length(parameters_fitted)),
      ubounds = fill(Inf, length(parameters_fitted)),
      scale = fill(:lin, length(parameters_fitted)),
      progress::Symbol = :minimal,
      kwargs... 
    ) where {C<:AbstractScenario, P<:Pair}

  Fit parameters to experimental measurements. Returns `FitResult` type.

  Example: `fit([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

  Arguments:

  - `scenario_pairs` : can be a `Platform`, a vector of scenarios, or a vector of pairs (`Vector{Pair{Symbol,Scenario}}`), matching the accepted types of the `estimator` function.
  - `parameters_fitted` : can be a vector of pairs (`Vector{Pair{Symbol,<:Real}}`) or a `DataFrame` with parameter setup, as accepted by `estimator`.
  - `parameters` : parameters, which overwrite both `Model` and `Scenario` parameters. Default is `nothing`
  - `alg` : ODE solver. See SciML docs for details. Default is `AutoTsit5(Rosenbrock23())`
  - `reltol` : relative tolerance. Default is 1e-6
  - `abstol` : absolute tolerance. Default is 1e-8
  - `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
  - `adtype` : automatic differentiation type. See SciML docs for details. Default is `AutoForwardDiff()`
  - `ftol_abs` : absolute tolerance on objective value. See `Optimization.jl` docs for details. Default is `0.0`
  - `ftol_rel` : relative tolerance on objective value. See `Optimization.jl` docs for details. Default is `1e-4`
  - `fit_alg` : fitting algorithm. See `Optimization.jl` docs for details. Default is `NLopt.LN_NELDERMEAD()`
  - `maxiters` : maximum number of objective evaluations. See `Optimization.jl` docs for details. Default is `1e4`
  - `maxtime` : maximum optimization time (in seconds). See `Optimization.jl` docs for details. Default is `nothing`
  - `lbounds` : lower parameters bounds. See `Optimization.jl` docs for details. Default is `fill(0.0, length(parameters_fitted))`
  - `ubounds` : upper parameters bounds. See `Optimization.jl` docs for details. Default is `fill(Inf, length(parameters_fitted))`
  - `scale`   : scale of the parameters (supports `:lin, :direct, :log, :log10`) to be used during fitting. Default is `fill(:lin, length(parameters_fitted))`.
                `:direct` value is a synonym of `:lin`.
  - `progress` : progress mode display. One of three values: `:silent`, `:minimal`, `:full`. Default is `:minimal`
  - `kwargs...` : other solver related arguments supported by SciMLBase.solve. See SciML docs for details
"""
function fit(
  scenario_pairs,
  parameters_fitted::AbstractVector{<:Pair{Symbol,<:Real}};
  parameters::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_FITTING_RELTOL,
  abstol=DEFAULT_FITTING_ABSTOL,
  parallel_type=EnsembleSerial(),
  adtype=AutoForwardDiff(),
  ftol_abs = 0.0,
  ftol_rel = 1e-4,
  fit_alg = NLopt.LN_NELDERMEAD(),
  maxiters = 10000,
  maxtime = nothing,
  lbounds = fill(0.0, length(parameters_fitted)),
  ubounds = fill(Inf, length(parameters_fitted)),
  scale = fill(:lin, length(parameters_fitted)),
  progress::Symbol = :minimal,
  kwargs... # other arguments to sim
) where {C<:AbstractScenario, P<:Pair}

  optprob = generate_optimization_problem(
    scenario_pairs,
    parameters_fitted;
    parameters=parameters,
    alg=alg,
    reltol=reltol,
    abstol=abstol,
    parallel_type=parallel_type,
    adtype=adtype,
    lbounds=lbounds,
    ubounds=ubounds,
    scale=scale,
    progress=progress,
    kwargs... # other arguments to sim
  )

  optsol = solve(optprob, fit_alg; 
    reltol=ftol_rel, 
    abstol=ftol_abs, 
    maxiters=maxiters, 
    maxtime=maxtime)

  minx = optsol.u
  minf = optsol.objective
  ret = Symbol(optsol.retcode)
  numiters = 0 # TODO callback to save iters
  # to create pairs from Float64
  parameter_names = _extract_parameter_names(parameters_fitted)
  minx_pairs = [key=>value for (key, value) in zip(parameter_names, unscale_params.(minx, scale))]

  return FitResult(minf, minx_pairs, ret, numiters)
end

function fit(
  scenario_pairs,
  parameters_fitted::DataFrame;
  kwargs...
)
  
  gdf = groupby(parameters_fitted, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  parameters_fitted_ = gdf[(true,)].parameter .=> gdf[(true,)].nominal
  lbounds = gdf[(true,)].lower
  ubounds = gdf[(true,)].upper
  scale = gdf[(true,)].scale
  # fixed parameters
  parameters = haskey(gdf, (false,)) ? gdf[(false,)].parameter .=> gdf[(false,)].nominal : nothing

  fit(scenario_pairs, parameters_fitted_; parameters, lbounds, ubounds, scale, kwargs...)
end


function _extract_parameter_names(params::AbstractVector{<:Pair{Symbol,<:Real}})
  return first.(params)
end

function _extract_parameter_names(params::DataFrame)
  gdf = groupby(params, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  return gdf[(true,)].parameter
end
