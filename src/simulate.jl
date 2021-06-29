const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem(() -> nothing, [0.0], (0.,1.))

### simulate condition

"""
    sim(cond::Cond; 
      parameters_upd::Union{Nothing, Vector{P}}=nothing,
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL, 
      abstol=DEFAULT_SIMULATION_ABSTOL,
      kwargs...)

Simulate single condition `cond`. Returns [`SimResults`](@ref) type.
Example: `Cond(model; tspan = (0., 200.), saveat = [0.0, 150., 250.]) |> sim`

Arguments:

- `cond` : simulation condition of type [`Cond`](@ref)
- `parameters_upd` : constants, which overwrite both `Model` and `Cond` constants. Default is `nothing`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function sim(
  cond::Cond; 
  parameters_upd::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs... # other solver arguments
) where P<:Pair

  prob = !isnothing(parameters_upd) ? update_init_values(cond.prob, cond.init_func, NamedTuple(parameters_upd)) : cond.prob
  sol = solve(prob, alg; reltol = reltol, abstol = abstol,
    save_start = false, save_end = false, save_everystep = false, kwargs...)

  return build_results(sol, cond)
end

function build_results(sol::SciMLBase.AbstractODESolution)
  sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  return Simulation(sv, sol.retcode)
end

build_results(sol::SciMLBase.AbstractODESolution, cond) = SimResults(build_results(sol), cond)

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
- kwargs : other solver related arguments supported by `sim(cond::Cond)`
"""
function sim(
  model::Model;

  ## arguments for Cond(::Model,...)
  parameters::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  tspan::Union{Nothing,Tuple} = nothing,
  save_scope::Bool=true,
  time_type::DataType=Float64,
  kwargs... # sim(c::Cond) kwargs
)
  condition = Cond(
    model; parameters, measurements,
    events_active, events_save, observables, saveat, tspan, save_scope, time_type)

  return sim(condition; kwargs...)
end

### general interface for EnsembleProblem

"""
    sim(condition_pairs::Vector{P}; 
      parameters_upd::Union{Nothing, Vector}=nothing,
      alg=DEFAULT_ALG, 
      reltol=DEFAULT_SIMULATION_RELTOL, 
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...) where P<:Pair

Simulate multiple conditions. Returns `Vector{Pair}`.
Example: `sim([:x => cond1, :y=>cond2, :z=>cond3])`

Arguments:

- `condition_pairs` : vector of pairs containing names and conditions of type [`Cond`](@ref)
- `parameters_upd` : constants, which overwrite both `Model` and `Cond` constants. Default is `nothing`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `parallel_type` : type of multiple simulations parallelism. Default is no parallelism. See SciML docs for details
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function sim(
  condition_pairs::Vector{P};
  parameters_upd::Union{Nothing, Vector}=nothing,
  alg = DEFAULT_ALG, 
  reltol = DEFAULT_SIMULATION_RELTOL, 
  abstol = DEFAULT_SIMULATION_ABSTOL,

  parallel_type=EnsembleSerial(),
  kwargs... # other arguments for OrdinaryDiffEq.solve()
) where P<:Pair

  isempty(condition_pairs) && return SimResults[] # BRAKE

  function prob_func(prob,i,repeat)
    prob_i = last(condition_pairs[i]).prob
    init_func_i = last(condition_pairs[i]).init_func
    !isnothing(parameters_upd) ? 
      update_init_values(prob_i, init_func_i, NamedTuple(parameters_upd)) : prob_i
  end

  function _output(sol,i)
    build_results(sol,last(condition_pairs[i])),false
  end
  
  _reduction(u,batch,I) = (append!(u,batch),false)

  prob = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func,
    output_func = _output,
    reduction = _reduction
  )

  solution = solve(prob, alg, parallel_type;
    trajectories = length(condition_pairs),
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
    )
  return [Pair{Symbol,SimResults}(first(cp), u) for (cp,u) in zip(condition_pairs, solution.u)]
end

### simulate many conditions

"""
    sim(conditions::AbstractVector{C}; kwargs...) where {C<:AbstractCond}

Simulate multiple conditions. Returns `Vector{Pair}`.
Example: `sim([cond1, cond2, cond3])`

Arguments:

- `conditions` : `Vector` containing names and conditions of type [`Cond`](@ref)
- kwargs : other kwargs supported by `sim(condition_pairs::Vector{Pair})`
"""
function sim(
  conditions::AbstractVector{C};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractCond}
  condition_pairs = [Symbol("_$i") => cond for (i, cond) in pairs(conditions)]
  return sim(condition_pairs; kwargs...)
end

### simulate Platform

"""
    sim(platform::Platform; 
      conditions::Union{AbstractVector{Symbol}, Nothing} = nothing,
      kwargs...) where {C<:AbstractCond}

Simulate conditions included in platform. Returns `Vector{Pair}`.
Example: `sim(platform)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `conditions` : `Vector` containing names of conditions included in platform. Default value `nothing` stands for all conditions in the platform 
- kwargs : other kwargs supported by `sim(condition_pairs::Vector{Pair})`
"""
function sim(
  platform::Platform;
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs... # other arguments to sim(::Vector{Pair})
) 
  @assert length(platform.conditions) != 0 "Platform should contain at least one condition."

  if isnothing(conditions)
    condition_pairs = [platform.conditions...]
  else
    condition_pairs = Pair{Symbol,AbstractCond}[]
    for cond_name in conditions
      @assert haskey(platform.conditions, cond_name) "No condition :$cond_name found in the platform."
      push!(condition_pairs, cond_name=>platform.conditions[cond_name])
    end
  end

  return sim(condition_pairs; kwargs...)
end


function default_output(sol,i)
  sim = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  sim,false
end

default_reduction(u,batch,I) = (append!(u,batch),false)
