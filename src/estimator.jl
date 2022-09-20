# likelihood estimator generator

"""
    function estimator(
      scenario_pairs::AbstractVector{Pair{Symbol, C}},
      parameters_fitted::Vector{Pair{Symbol,Float64}};
      parameters::Union{Nothing, Vector{P}}=nothing,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_FITTING_RELTOL,
      abstol=DEFAULT_FITTING_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs... # other arguments to sim
    ) where {C<:AbstractScenario, P<:Pair}

  Generates likelihood estimator function for parameter identification and analysis.
  It corresponds to `-2ln(L)` as a function depending on parameter set.

  Example: `estimator([:x=>scn2, :y=>scn3, :z=>scn4], [:k1=>0.1,:k2=>0.2,:k3=>0.3])`

  Arguments:

  - `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : parameters and their nominal values that will be used as default
  - `parameters` : constants, which overwrite both `Model` and `Scenario` constants. Default is `nothing`
  - `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
  - `reltol` : relative tolerance. Default is 1e-6
  - `abstol` : relative tolerance. Default is 1e-8
  - `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
  - `kwargs...` : other ODE solver related arguments supported by `DiffEqBase.solve`. See SciML docs for details

  Returns:

    function(x:Vector{Float64}=last.(parameters_fitted))
  
  The method returns anonimous function which depends on parameters vector in the same order as in `parameters_fitted`.
  This function is ready to be passed to optimizer routine or identifiability analysis.
"""
function estimator(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  parameters_fitted::Vector{Pair{Symbol,Float64}};
  parameters::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_FITTING_RELTOL,
  abstol=DEFAULT_FITTING_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs... # other arguments to sim
) where {C<:AbstractScenario, P<:Pair}

  # names of parameters used in fitting and saved in parameters field of solution
  parameters_fitted_names = first.(parameters_fitted)

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
    prob_i = if !isnothing(parameters)
      constants_total_i = merge_strict(last(scn).parameters, NamedTuple(parameters))
      u0, p0 = last(scn).init_func(constants_total_i)
      remake(prob_i; u0=u0, p=p0)
    else
      prob_i
    end
    push!(selected_prob, prob_i)
  end

  function prob_func(x) # x::
    function(prob,i,repeat) # internal_prob_func
      #update_init_values(selected_prob[i], last(selected_scenario_pairs[i]).init_func, x)
      scn = last(selected_scenario_pairs[i])
      constants_total = merge_strict(scn.parameters, x)
      u0, p0 = scn.init_func(constants_total)
      remake(selected_prob[i]; u0=u0, p=p0)
    end
  end

  function _output(sol, i)
    sol.retcode != :Success && error("Simulated scenario $i returned $(sol.retcode) status")
    sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
    simulation = Simulation(sv, NamedTuple(parameters_fitted), sol.retcode)
    result = SimResult(simulation, last(selected_scenario_pairs[i]))
    loss_val = loss(result, result.scenario.measurements)
    (loss_val, false)
  end

  function _reduction(u, batch, I)
    (sum(batch),false)
  end

  prob(x) = EnsembleProblem(
    EMPTY_PROBLEM;
    prob_func = prob_func(x),
    output_func = _output,
    reduction = _reduction
  )

  ### function ready for fitting

  function out(x::Vector{Float64}=last.(parameters_fitted))
    x_nt = NamedTuple{Tuple(parameters_fitted_names)}(x)
    solution = solve(
      prob(x_nt),
      alg,
      parallel_type;
      trajectories = length(selected_scenario_pairs),
      reltol,
      abstol,
      save_start = false, 
      save_end = false, 
      save_everystep = false, 
      kwargs...
    )

    return solution.u
  end
  
  return out
end

"""
    function estimator(
      scenario_pairs::AbstractVector{Pair{Symbol, C}},
      parameters_fitted::DataFrame;
      kwargs...
    ) where C<:AbstractScenario

  Generates likelihood estimator function for parameter identification and analysis. 
  It is the interface for parameters from `DataFrame`.
  See more detailes in base `estimator` method.

  Arguments:

  - `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : DataFrame with optimization parameters setup and their initial values, see [`read_parameters`](@ref)
  - `kwargs...` : other arguments supported by `estimator`, see base method.
"""
function estimator(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  parameters_fitted::DataFrame;
  kwargs...
) where C<:AbstractScenario
  
  gdf = groupby(parameters_fitted, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  parameters_fitted = gdf[(true,)].parameter .=> gdf[(true,)].nominal
  parameters = haskey(gdf, (false,)) ? gdf[(false,)].parameter .=> gdf[(false,)].nominal : nothing

  estimator(scenario_pairs, parameters_fitted; parameters, kwargs...)
end

"""
    function estimator(
      scenarios::AbstractVector{C},
      parameters_fitted;
      kwargs...
    ) where {C<:AbstractScenario}

  Generates likelihood estimator function for parameter identification and analysis. 
  It is the interface for scenarios in vector.
  See more detailes in base `estimator` method.
    
  Arguments:
  
  - `scenarios` : vector of scenarios of type [`Scenario`](@ref)
  - `parameters_fitted` : optimization parameters and their initial values
  - `kwargs...` : other arguments supported by `estimator`, see base method.
"""
function estimator(
  scenarios::AbstractVector{C},
  parameters_fitted; # DataFrame or Vector{Pair{Symbol,Float64}}
  kwargs...
) where {C<:AbstractScenario}
  scenario_pairs = Pair{Symbol,AbstractScenario}[Symbol("_$i") => scn for (i, scn) in pairs(scenarios)]
  return estimator(scenario_pairs, parameters_fitted; kwargs...)
end

"""
    function estimator(
      platform::Platform,
      parameters_fitted;
      scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
      kwargs... 
    )
  
  Generates likelihood estimator function for parameter identification and analysis. 
  It is the interface for Platform.
  See more detailes in base `estimator` method.

  Arguments:

  - `platform` : platform of [`Platform`](@ref) type
  - `parameters_fitted` : optimization parameters and their initial values
  - `scenarios` : vector of scenarios identifiers of type `Symbol`. Default is `nothing`
  - `kwargs...` : other arguments supported by `estimator`, see base method.
"""
function estimator(
  platform::Platform,
  parameters_fitted;
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... 
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

  return estimator(scenario_pairs, parameters_fitted; kwargs...)
end
