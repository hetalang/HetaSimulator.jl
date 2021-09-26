const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem(() -> nothing, [0.0], (0.,1.))

### simulate scenarios

"""
    sim(scenario::Scenario; 
      parameters_upd::Union{Nothing, Vector{P}}=nothing,
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL, 
      abstol=DEFAULT_SIMULATION_ABSTOL,
      kwargs...)

Simulate single `Scenario`. Returns [`SimResults`](@ref) type.

Example: `Scenario(model; tspan = (0., 200.), saveat = [0.0, 150., 250.]) |> sim`

Arguments:

- `scenario` : simulation scenario of type [`HetaSimulator.Scenario`](@ref)
- `parameters_upd` : constants, which overwrite both `Model` and `HetaSimulator.Scenario` constants. Default is `nothing`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function sim(
  scenario::Scenario; 
  parameters_upd::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs... # other solver arguments
) where P<:Pair

  prob = !isnothing(parameters_upd) ? update_init_values(scenario.prob, scenario.init_func, NamedTuple(parameters_upd)) : scenario.prob
  sol = solve(prob, alg; reltol = reltol, abstol = abstol,
    save_start = false, save_end = false, save_everystep = false, kwargs...)

  return build_results(sol, scenario)
end

function build_results(sol::SciMLBase.AbstractODESolution)
  sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  return Simulation(sv, sol.retcode)
end

build_results(sol::SciMLBase.AbstractODESolution, scenario) = SimResults(build_results(sol), scenario)

### simulate Model
"""
    sim(model::Model; 
      parameters::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
      measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
      events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
      events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
      observables::Union{Nothing,Vector{Symbol}} = nothing,
      saveat::Union{Nothing,AbstractVector} = nothing,
      tspan::Union{Nothing,Tuple} = nothing,
      save_scope::Bool=true,
      time_type::DataType=Float64,
      kwargs...)

Simulate model of type [`Model`](@ref). Returns [`SimResults`](@ref) type.

Example: `sim(model; tspan = (0., 200.), parameters_upd = [:k1=>0.01])`

Arguments:

- `model` : model of type [`Model`](@ref)
- `parameters` : `Vector` of `Pair`s containing constants' names and values. Overwrites default model's values. Default is empty vector 
- `measurements` : `Vector` of measurements. Default is empty vector 
- `events_active` : `Vector` of `Pair`s containing events' names and true/false values. Overwrites default model's values. Default is empty vector 
- `events_save` : `Tuple` or `Vector{Tuple}` marking whether to save solution before and after event. Default is `(true,true)` for all events
- `observables` : names of output observables. Overwrites default model's values. Default is empty vector
- `saveat` : time points, where solution should be saved. Default `nothing` values stands for saving solution at timepoints reached by the solver 
- `tspan` : time span for the ODE problem
- `save_scope` : should scope be saved together with solution. Default is `true`
- kwargs : other solver related arguments supported by `sim(scenario::Scenario)`
"""
function sim(
  model::Model;

  ## arguments for Scenario(::Model,...)
  parameters::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  tspan::Union{Nothing,Tuple} = nothing,
  save_scope::Bool=true,
  time_type::DataType=Float64,
  kwargs... # sim(c::Scenario) kwargs
)
  scenario = Scenario(
    model; parameters, measurements,
    events_active, events_save, observables, saveat, tspan, save_scope, time_type)

  return sim(scenario; kwargs...)
end

### general interface for EnsembleProblem

"""
    sim(scenario_pairs::Vector{P}; 
      parameters_upd::Union{Nothing, Vector}=nothing,
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL, 
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...) where P<:Pair

Simulate multiple scenarios. Returns `Vector{Pair}`.

Example: `sim([:x => scn1, :y=>scn2, :z=>scn3])`

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`HetaSimulator.Scenario`](@ref)
- `parameters_upd` : constants, which overwrite both `Model` and `Scenario` constants. Default is `nothing`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `parallel_type` : type of multiple simulations parallelism. Default is no parallelism. See SciML docs for details
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function sim(
  scenario_pairs::Vector{P};
  parameters_upd::Union{Nothing, Vector}=nothing,
  alg = DEFAULT_ALG, 
  reltol = DEFAULT_SIMULATION_RELTOL, 
  abstol = DEFAULT_SIMULATION_ABSTOL,

  parallel_type=EnsembleSerial(),
  kwargs... # other arguments for OrdinaryDiffEq.solve()
) where P<:Pair

  isempty(scenario_pairs) && return SimResults[] # BRAKE

  progress_on = (parallel_type == EnsembleSerial()) # tmp fix
  p = Progress(length(scenario_pairs), dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled=progress_on)

  function prob_func(prob,i,repeat)
    next!(p)
    prob_i = last(scenario_pairs[i]).prob
    init_func_i = last(scenario_pairs[i]).init_func
    !isnothing(parameters_upd) ? 
      update_init_values(prob_i, init_func_i, NamedTuple(parameters_upd)) : prob_i
  end

  function _output(sol,i)
    build_results(sol,last(scenario_pairs[i])),false
  end
  
  _reduction(u,batch,I) = (append!(u,batch),false)

  prob = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func,
    output_func = _output,
    reduction = _reduction
  )

  solution = solve(prob, alg, parallel_type;
    trajectories = length(scenario_pairs),
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
    )
  return [Pair{Symbol,SimResults}(first(cp), u) for (cp,u) in zip(scenario_pairs, solution.u)]
end

### simulate many scenarios

"""
    sim(scenarios::AbstractVector{C}; kwargs...) where {C<:AbstractScenario}

Simulate multiple scenarios. Returns `Vector{Pair}`.

Example: `sim([scn1, scn2, scn3])`

Arguments:

- `scenarios` : `Vector` containing names and scenarios of type [`HetaSimulator.Scenario`](@ref)
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
      scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
      kwargs...) where {C<:AbstractScenario}

Simulate scenarios included in platform. Returns `Vector{Pair}`.

Example: `sim(platform)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `scenarios` : `Vector` containing names of scenarios included in platform. Default value `nothing` stands for all scenarios in the platform 
- kwargs : other kwargs supported by `sim(scenario_pairs::Vector{Pair})`
"""
function sim(
  platform::Platform;
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs... # other arguments to sim(::Vector{Pair})
) 
  @assert length(platform.scenarios) != 0 "Platform should contain at least one scenario."

  if isnothing(scenarios)
    scenario_pairs = [platform.scenarios...]
  else
    scenario_pairs = Pair{Symbol,AbstractScenario}[]
    for scn_name in scenarios
      @assert haskey(platform.scenarios, scn_name) "No scenario :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.scenarios[scn_name])
    end
  end

  return sim(scenario_pairs; kwargs...)
end


function default_output(sol,i)
  sim = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  sim,false
end

default_reduction(u,batch,I) = (append!(u,batch),false)
