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

  Fit parameters to experimental measurements. Returns `FitResult` type.

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
  - `xtol_abs` : absolute tolerance on optimization parameters. See `NLopt.jl` docs for details. Default is `0.0`
  - `fit_alg` : fitting algorithm. See `NLopt.jl` docs for details. Default is `:LN_NELDERMEAD`
  - `maxeval` : maximum number of function evaluations. See `NLopt.jl` docs for details. Default is `1e4`
  - `maxtime` : maximum optimization time (in seconds). See `NLopt.jl` docs for details. Default is `0`
  - `lbounds` : lower parameters bounds. See `NLopt.jl` docs for details. Default is `fill(0.0, length(params))`
  - `ubounds` : upper parameters bounds. See `NLopt.jl` docs for details. Default is `fill(Inf, length(params))`
  - `scale`   : scale of the parameters (supports `:lin, :log, :log10`) to be used during fitting. Default is `fill(:lin, length(params))`
  - `progress` : progress mode display. One of three values: `:silent`, `:minimal`, `:full`. Default is `:minimal`
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
  progress::Symbol = :minimal,
  kwargs... # other arguments to sim
) where {C<:AbstractScenario, P<:Pair}

  # names of parameters used in fitting and saved in params field of solution
  params_names = first.(params)

  selected_scenario_pairs = Pair{Symbol,Scenario}[]
  for scenario_pair in scenario_pairs # iterate through scenarios names
    if isempty(last(scenario_pair).measurements)
      @warn "Scenario \":$(first(scenario_pair))\" has no measurements. It will be excluded from fitting."
    else
      push!(selected_scenario_pairs, scenario_pair)
    end
  end
  
  isempty(selected_scenario_pairs) && throw("No measurements points included in scenarios.")

  estim_fun = estimator( # return function
    scenario_pairs,
    params;
    parameters_upd,
    alg,
    reltol,
    abstol,
    parallel_type,
    kwargs...
  )

  # progress info
  prog = ProgressUnknown("Fit counter:"; spinner=false, enabled=progress!=:silent, showspeed=true)
  count = 0
  estim_best = Inf
  function obj_func(x, grad)
    count+=1
    # try - catch is a tmp solution for NLopt 
    x_unscaled = unscale_params.(x, scale)
    estim_x = try
      estim_fun(x_unscaled)
    catch e
        @warn "Error when calling loss_func($x): $e"
    end
    
    if estim_x < estim_best
      estim_best = estim_x
    end

    values_to_display = [(:ESTIMATOR_BEST, round(estim_best; digits=2))]
    if progress == :full
      for i in 1:length(x)
        push!(values_to_display, (params_names[i], round(x_unscaled[i], sigdigits=3)))
      end
    end

    ProgressMeter.update!(prog, count, spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"; showvalues = values_to_display)
    return estim_x
  end

  opt = Opt(fit_alg, length(params))
  opt.min_objective = obj_func

  opt.ftol_rel = ftol_rel
  #opt.ftol_abs = ftol_abs
  ftol_abs!(opt, ftol_abs)

  opt.xtol_rel = xtol_rel
  opt.xtol_abs = xtol_abs

  #opt.maxeval = maxeval
  maxeval!(opt, maxeval)
  opt.maxtime = maxtime

  lower_bounds!(opt, scale_params.(lbounds, scale))
  upper_bounds!(opt, scale_params.(ubounds, scale))

  params0 = scale_params.(last.(params), scale)
  (minf, minx, ret) = NLopt.optimize(opt, params0)

  # to create pairs from Float64
  minx_pairs = [key=>value for (key, value) in zip(first.(params), unscale_params.(minx, scale))]
  
  return FitResult(minf, minx_pairs, ret, opt.numevals)
end

"""
    fit(scenario_pairs::AbstractVector{Pair{Symbol, C}},
      params_df::DataFrame;
      kwargs...
    ) where C<:AbstractScenario

  Fit parameters to experimental measurements. Returns `FitResult` type.

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

  params = gdf[(true,)].parameter .=> gdf[(true,)].nominal
  lbounds = gdf[(true,)].lower
  ubounds = gdf[(true,)].upper
  scale = gdf[(true,)].scale
  # fixed parameters
  parameters_upd = haskey(gdf, (false,)) ? gdf[(false,)].parameter .=> gdf[(false,)].nominal : nothing

  fit(scenario_pairs, params; parameters_upd, lbounds, ubounds, scale, kwargs...)
end

"""
    fit(scenarios::AbstractVector{C},
      params;
      kwargs...
    ) where C<:AbstractScenario

  Fit parameters to experimental measurements. Returns `FitResult` type.

  Example: `fit([scn2, scn3, scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

  Arguments:

  - `scenarios` : vector of scenarios of type [`Scenario`](@ref)
  - `params` : optimization parameters and their initial values
  - kwargs : other solver related arguments supported by `fit(scenario_pairs::Vector{<:Pair}, params::Vector{<:Pair}`
"""
function fit(
  scenarios::AbstractVector{C},
  params; # DataFrame or Vector{Pair{Symbol,Float64}}
  kwargs... # other arguments to fit or sim
) where {C<:AbstractScenario}
  scenario_pairs = Pair{Symbol,AbstractScenario}[Symbol("_$i") => scn for (i, scn) in pairs(scenarios)]
  return fit(scenario_pairs, params; kwargs...)
end

### fit platform ###

"""
    fit(platform::Platform,
      params;
      scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
      kwargs...
    ) where C<:AbstractScenario

  Fit parameters to experimental measurements. Returns `FitResult` type.

  Example: `fit(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3];scenarios=[:scn2,:scn3])`

  Arguments:

  - `platform` : platform of [`Platform`](@ref) type
  - `params` : optimization parameters and their initial values
  - `scenarios` : vector of scenarios of type [`Scenario`](@ref) or `nothing` to fit all scenarios. Default is `nothing`
  - kwargs : other solver related arguments supported by `fit(scenario_pairs::Vector{<:Pair}, params::Vector{<:Pair}`
"""
function fit(
  platform::Platform,
  params; # DataFrame or Vector{Pair{Symbol,Float64}}
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... # other arguments to fit or sim
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
