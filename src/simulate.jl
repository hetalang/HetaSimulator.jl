const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem(() -> nothing, [0.0], (0.,1.))

### simulate condition

function sim(
  cond::Cond; 

  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs... # other solver arguments
)
  prob = cond.prob
  sol = solve(prob, alg; reltol = reltol, abstol = abstol,
    save_start = false, save_end = false, save_everystep = false, kwargs...)

  return build_results(sol, cond)
end

function build_results(sol::SciMLBase.AbstractODESolution, cond)
  sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  return SimResults(Simulation(sv, sol.retcode), cond)
end

### simulate Model

function sim(
  model::Model;

  ## arguments for Cond(::Model,...)
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  events_on::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  tspan::Union{Nothing,Tuple} = nothing,
  save_scope::Bool=true,
  time_type::DataType=Float64,
  kwargs... # sim(c::Cond) kwargs
)
  condition = Cond(
    model; constants, measurements,
    events_on, events_save, observables, saveat, tspan, save_scope, time_type)

  return sim(condition; kwargs...)
end

### general interface for EnsembleProblem

function sim(
  condition_pairs::Vector{P};

  alg = DEFAULT_ALG, 
  reltol = DEFAULT_SIMULATION_RELTOL, 
  abstol = DEFAULT_SIMULATION_ABSTOL,

  parallel_type=EnsembleSerial(),
  kwargs... # other arguments for OrdinaryDiffEq.solve()
) where P<:Pair

  isempty(condition_pairs) && return SimResults[] # BRAKE

  function prob_func(prob,i,repeat)
    last(condition_pairs[i]).prob
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
  return [first(cp)=>u for (cp,u) in zip(condition_pairs, solution.u)]
end

### simulate many conditions

function sim(
  conditions::AbstractVector{C};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractCond}
  condition_pairs = [Symbol("Cond_ID$i") => cond for (i, cond) in pairs(conditions)]
  return sim(condition_pairs; kwargs...)
end

### simulate Platform

function sim(
  platform::Platform;
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs... # other arguments to sim(::Vector{Pair})
) 
  @assert length(platform.conditions) != 0 "Platform should contain at least one condition."

  if conditions === nothing
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

