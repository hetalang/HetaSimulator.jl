const DEFAULT_FITTING_RELTOL = 1e-6
const DEFAULT_FITTING_ABSTOL = 1e-8

### general interface

"""
    generate_optimization_problem(
      scenario_pairs::AbstractVector{Pair{Symbol, C}},
      parameters_fitted::AbstractVector{<:Pair{Symbol,<:Real}};
      parameters::Union{Nothing, Vector{P}}=nothing,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_FITTING_RELTOL,
      abstol=DEFAULT_FITTING_ABSTOL,
      parallel_type=EnsembleSerial(),
      adtype=AutoForwardDiff(),
      lbounds = fill(0.0, length(parameters_fitted)),
      ubounds = fill(Inf, length(parameters_fitted)),
      scale = fill(:lin, length(parameters_fitted)),
      progress::Symbol = :minimal,
      kwargs... 
    ) where {C<:AbstractScenario, P<:Pair}

  Generates `OptimizationProblem`. Returns `OptimizationProblem` type.

  Example: `generate_optimization_problem([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

  Arguments:

  - `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : optimization parameters and their initial values
  - `parameters` : parameters, which overwrite both `Model` and `Scenario` parameters. Default is `nothing`
  - `alg` : ODE solver. See SciML docs for details. Default is `AutoTsit5(Rosenbrock23())`
  - `reltol` : relative tolerance. Default is 1e-6
  - `abstol` : absolute tolerance. Default is 1e-8
  - `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
  - `adtype` : automatic differentiation type. See SciML docs for details. Default is `AutoForwardDiff()`
  - `lbounds` : lower parameters bounds. See `Optimization.jl` docs for details. Default is `fill(0.0, length(parameters_fitted))`
  - `ubounds` : upper parameters bounds. See `Optimization.jl` docs for details. Default is `fill(Inf, length(parameters_fitted))`
  - `scale`   : scale of the parameters (supports `:lin, :direct, :log, :log10`) to be used during fitting. Default is `fill(:lin, length(parameters_fitted))`.
                `:direct` value is a synonym of `:lin`.
  - `progress` : progress mode display. One of three values: `:silent`, `:minimal`, `:full`. Default is `:minimal`
  - `kwargs...` : other solver related arguments supported by SciMLBase.solve. See SciML docs for details
"""
function generate_optimization_problem(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  parameters_fitted::AbstractVector{<:Pair{Symbol,<:Real}};
  parameters::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_FITTING_RELTOL,
  abstol=DEFAULT_FITTING_ABSTOL,
  parallel_type=EnsembleSerial(),
  adtype=AutoForwardDiff(),
  lbounds = fill(0.0, length(parameters_fitted)),
  ubounds = fill(Inf, length(parameters_fitted)),
  scale = fill(:lin, length(parameters_fitted)),
  progress::Symbol = :minimal,
  kwargs... # other arguments to sim
) where {C<:AbstractScenario, P<:Pair}

  # names of parameters used in fitting and saved in parameters_fitted field of solution
  parameters_names = first.(parameters_fitted)

  selected_scenario_pairs = Pair{Symbol,Scenario}[]
  for scenario_pair in scenario_pairs # iterate through scenarios names
    if isempty(last(scenario_pair).measurements)
      @info "Scenario \":$(first(scenario_pair))\" has no measurements. It will be excluded from fitting."
    else
      push!(selected_scenario_pairs, scenario_pair)
    end
  end
  
  isempty(selected_scenario_pairs) && throw("No measurements points included in scenarios.")

  estim_fun = estimator( # return function
    selected_scenario_pairs,
    parameters_fitted;
    parameters,
    alg,
    reltol,
    abstol,
    parallel_type,
    kwargs...
  )

  # progress info
  prog = ProgressUnknown(; desc ="Fit counter:", spinner=false, enabled=progress!=:silent, showspeed=true)
  count = 0
  estim_best = Inf
  function obj_func(x, hyper_params)
    count+=1
    # try - catch is a tmp solution for NLopt 
    x_unscaled = unscale_params.(x, scale)
    estim_obj = try
      estim_fun(x_unscaled)
    catch e
        @warn "Error when calling loss_func($x): $e"
    end

    if !isnothing(estim_obj) && !isa(estim_obj, ForwardDiff.Dual) && (estim_obj < estim_best)
      estim_best = estim_obj
    end

    values_to_display = [(:ESTIMATOR_BEST, round(estim_best; digits=2))]
    if progress == :full && !(eltype(x_unscaled) <: ForwardDiff.Dual)
      for i in 1:length(x)
        push!(values_to_display, (parameters_names[i], round(x_unscaled[i], sigdigits=3)))
      end
    end

    ProgressMeter.update!(prog, count, spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"; showvalues = values_to_display)
    return estim_obj
  end

  optf = OptimizationFunction(obj_func, adtype)
  params0 = scale_params.(parameters_fitted .|> last .|> Float64, scale) # force convert to Float64
  lb = scale_params.(lbounds, scale)
  ub = scale_params.(ubounds, scale)

  return OptimizationProblem(optf, params0; lb=lb, ub=ub)
end

"""
    generate_optimization_problem(
      scenario_pairs::AbstractVector{Pair{Symbol, C}},
      parameters_fitted::DataFrame;
      kwargs...
    ) where C<:AbstractScenario

  Generates `OptimizationProblem`. Returns `OptimizationProblem` type.

  Arguments:

  - `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : DataFrame with optimization parameters setup and their initial values, see [`read_parameters`](@ref)
  - `kwargs...` : other ODE solver and `fit` arguments supported by `generate_optimization_problem(scenario_pairs::Vector{<:Pair}, parameters_fitted::Vector{<:Pair}`
"""
function generate_optimization_problem(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  parameters_fitted::DataFrame;
  kwargs...
) where C<:AbstractScenario
  
  gdf = groupby(parameters_fitted, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  parameters_fitted_ = gdf[(true,)].parameter .=> gdf[(true,)].nominal
  lbounds = gdf[(true,)].lower
  ubounds = gdf[(true,)].upper
  scale = gdf[(true,)].scale
  # fixed parameters
  parameters = haskey(gdf, (false,)) ? gdf[(false,)].parameter .=> gdf[(false,)].nominal : nothing

  generate_optimization_problem(scenario_pairs, parameters_fitted_; parameters, lbounds, ubounds, scale, kwargs...)
end

"""
    generate_optimization_problem(
      scenarios::AbstractVector{C},
      parameters_fitted;
      kwargs...
    ) where C<:AbstractScenario

  Generates `OptimizationProblem`. Returns `OptimizationProblem` type.

  Example:
  
  `generate_optimization_problem([scn2, scn3, scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

  Arguments:

  - `scenarios` : vector of scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : optimization parameters and their initial values
  - `kwargs...` : other ODE solver and `fit` related arguments supported by `generate_optimization_problem(scenario_pairs::Vector{<:Pair}, parameters_fitted::Vector{<:Pair}`
"""
function generate_optimization_problem(
  scenarios::AbstractVector{C},
  parameters_fitted; # DataFrame or Vector{Pair{Symbol,Float64}}
  kwargs... # other arguments to fit or sim
) where {C<:AbstractScenario}
  scenario_pairs = Pair{Symbol,AbstractScenario}[Symbol("_$i") => scn for (i, scn) in pairs(scenarios)]
  return generate_optimization_problem(scenario_pairs, parameters_fitted; kwargs...)
end

### fit platform ###

"""
    generate_optimization_problem(platform::Platform,
      parameters_fitted;
      scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
      kwargs...
    ) where C<:AbstractScenario

  Generates `OptimizationProblem`. Returns `OptimizationProblem` type.

  Example:
  
  `generate_optimization_problem(platform, [:k1=>0.1,:k2=>0.2,:k3=>0.3];scenarios=[:scn2,:scn3])`

  Arguments:

  - `platform` : platform of [`Platform`](@ref) type
  - `parameters_fitted` : optimization parameters and their initial values
  - `scenarios` : vector of scenarios identifiers of type `Symbol`. Default is `nothing`
  - `kwargs...` : other ODE solver and `fit` related arguments supported by `generate_optimization_problem(scenario_pairs::Vector{<:Pair}, parameters_fitted::Vector{<:Pair}`
"""
function generate_optimization_problem(
  platform::Platform,
  parameters_fitted; # DataFrame or Vector{Pair{Symbol,Float64}}
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

  return generate_optimization_problem(scenario_pairs, parameters_fitted; kwargs...)
end

function scale_params(x, scale::Symbol)
  if scale == :lin || scale == :direct
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
  if scale == :lin || scale == :direct
    return x
  elseif scale == :log
    return exp(x)
  elseif scale == :log10
    return exp10(x)
  else
    throw("Scale \"$scale\" is not supported.")
  end
end