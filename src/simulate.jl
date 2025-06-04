const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem((du,u,p,t) -> nothing, [0.0], (0.,1.))

DEFAULT_SIM_REDUCTION(u,batch,I) = append!(u,batch), false 
DEFAULT_SIM_OUTPUT(sol,i) = sol
### simulate scenario

"""
    sim(scenario::Scenario; 
      parameters::AbstractVector{<:Pair{Symbol,<:Real}}=Pair{Symbol, Float64}[],
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      kwargs...)

Simulate single `Scenario`. Returns [`SimResult`](@ref) type.

Example: `Scenario(model, (0., 200.); saveat = [0.0, 150.]) |> sim`

Arguments:

- `scenario` : simulation scenario of type [`Scenario`](@ref)
- `parameters` : parameters overwrite both `Model` and `Scenario` parameters. Default is empty vector.
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `kwargs...` : other solver related arguments supported by SciMLBase.solve. See SciML docs for details
"""
function sim(
  scenario::Scenario;
  parameters::AbstractVector{<:Pair{Symbol,<:Real}}=Pair{Symbol, Float64}[], # input of `sim` level
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs... # other solver arguments
)
  parameters_norm = normalize_params(parameters)
  parameters_nt = NamedTuple(parameters_norm)

  prob = remake_prob(scenario, parameters_nt; safetycopy=true)
  #=
  prob = if length(parameters_nt) > 0
    constants_total = merge_strict(scenario.parameters, parameters_nt)
    u0, p0 = scenario.init_func(constants_total)
  
    remake(scenario.prob; u0=u0, p=p0)
  else 
    deepcopy(scenario.prob)
  end
  =#
  #= variant 2
  prob = let
    constants_total = merge_strict(scenario.parameters, parameters_nt)
    u0, p0 = scenario.init_func(constants_total)
    remake(scenario.prob; u0=u0, p=p0)
  end
  =#

  sol = solve(prob, alg; reltol = reltol, abstol = abstol,
    save_start = false, save_end = false, save_everystep = false, kwargs...)

  #parameters_names = Symbol[first(x) for x in parameters]
  #return build_results(sol, scenario, parameters_names)
  sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  simulation = Simulation(sv, parameters_nt, sol.retcode)

  return SimResult(simulation, scenario)
end

### simulate scenario pairs

"""
    sim(scenario_pairs::Vector{P}; 
      parameters::AbstractVector{<:Pair{Symbol, <:Real}}=Pair{Symbol, Float64}[],
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL, 
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...) where P<:Pair

Simulate multiple scenarios. Returns `Vector{Pair}`.

Example: `sim([:x => scn1, :y=>scn2, :z=>scn3])`

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
- `parameters` : parameters, which overwrite both `Model` and `Scenario` parameters. Default is empty vector.
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : absolute tolerance. Default is 1e-6
- `output_func` : the function determines what is saved from the solution to the output array. Defaults to saving the solution itself
- `reduction_func` : this function determines how to reduce the data in each batch. Defaults to appending the data from the batches
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- `kwargs...` : other solver related arguments supported by SciMLBase.solve. See SciML docs for de
      #update_init_values(scn_i.prob, scn_i.init_func, parameters_nt) tails
"""
function sim(
  scenario_pairs::Vector{P};
  parameters::AbstractVector{<:Pair{Symbol, <:Real}}=Pair{Symbol, Float64}[],
  alg = DEFAULT_ALG, 
  reltol = DEFAULT_SIMULATION_RELTOL, 
  abstol = DEFAULT_SIMULATION_ABSTOL,
  output_func=DEFAULT_SIM_OUTPUT,
  reduction_func = DEFAULT_SIM_REDUCTION,
  parallel_type=EnsembleSerial(),
  verbose = false,
  safetycopy=true,
  kwargs... # other arguments for OrdinaryDiffEq.solve()
) where P<:Pair

  isempty(scenario_pairs) && return SimResult[] # BRAKE

  parameters_norm = normalize_params(parameters)
  parameters_nt = NamedTuple(parameters_norm)
  lc = length(scenario_pairs)

  progress_on = (parallel_type == EnsembleSerial()) # tmp fix
  p = Progress(length(scenario_pairs), dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled=progress_on)

  function prob_func(prob,i,repeat)
    next!(p)
    verbose && println("Processing scenario $i")
    scn_i = last(scenario_pairs[i])
    prob_i = remake_prob(scn_i, parameters_nt; safetycopy)
    return prob_i
    #=
    constants_total_i = merge_strict(scn_i.parameters, parameters_nt)
    if length(parameters_nt) > 0
      u0, p0 = scn_i.init_func(constants_total_i)
      remake(scn_i.prob; u0=u0, p=p0)
    else
      deepcopy(scn_i.prob)
    end
    =#
  end

  function _output(sol,i)
    sv_i = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
    scenario = last(scenario_pairs[i])
    simulation = Simulation(sv_i, parameters_nt, sol.retcode)
    simres = SimResult(simulation, scenario)

    return (output_func(simres,i), false,)
  end
  
  prob = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func,
    output_func = _output,
    reduction = reduction_func,
    safetycopy = false # deepcopy scn_i.prob
  )

  solution = solve(prob, alg, parallel_type;
    trajectories = lc,
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
    )

  # E.g. if reduction was applied, then solution.u can be empty
  isempty(solution.u) && return Vector{Pair{Symbol,SimResult}}()
  
  return [first(sp) => u for (sp,u) in zip(scenario_pairs, solution.u)]
end

### simulate scenario array, XXX: do we need it?

"""
    sim(scenarios::AbstractVector{C}; kwargs...) where {C<:AbstractScenario}

Simulate multiple scenarios. Returns `Vector{Pair}`.

Example: `sim([scn1, scn2, scn3])`

Arguments:

- `scenarios` : `Vector` containing names and scenarios of type [`Scenario`](@ref)
- kwargs : other kwargs supported by `sim(scenario_pairs::Vector{Pair})`
"""
function sim(
  scenarios::AbstractVector{C};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractScenario}
  scenario_pairs = [Symbol("_$i") => scn for (i, scn) in pairs(scenarios)]
  return sim(scenario_pairs; kwargs...)
end

### simulate Platform

"""
    sim(platform::Platform; 
      scenarios::Union{AbstractVector{Symbol}, AbstractVector{InvertedIndex{Symbol}}, Nothing} = nothing,
      kwargs...) where {C<:AbstractScenario}

Simulate scenarios included in platform. Returns `Vector{Pair}`.

Example: `sim(platform)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `scenarios` : `Vector` containing names of scenarios included in platform. Default value `nothing` stands for all scenarios in the platform 
- `kwargs...` : other kwargs supported by `sim(scenario_pairs::Vector{Pair})`
"""
function sim(
  platform::Platform;
  scenarios::Union{AbstractVector{Symbol}, AbstractVector{InvertedIndex{Symbol}}, Nothing} = nothing,
  kwargs... # other arguments to sim(::Vector{Pair})
)
  @assert length(platform.scenarios) != 0 "Platform should contain at least one scenario."

  if isnothing(scenarios)
    scenario_pairs = [platform.scenarios...]
  else
    scenario_pairs = Pair{Symbol,AbstractScenario}[]
    for scn_name in scenarios
      # TODO: support of InvertedIndex{Symbol}
      @assert haskey(platform.scenarios, scn_name) "No scenario :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.scenarios[scn_name])
    end
  end

  return sim(scenario_pairs; kwargs...)
end
