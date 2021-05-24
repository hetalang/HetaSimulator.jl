const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem(() -> nothing, [0.0], (0.,1.))

### simulate condition

function sim(
  cond::Cond; 
  # the following two kwargs
  # are currently needed for fitting
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[], # to be removed
  saveat_measurements::Bool = false, # to be removed
  #
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

function build_results(sol::ODESolution, cond)
  sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  return SimResults(Simulation(sv.u, sv.t, sv.scope), sol.retcode, cond)
end
### simulate Model

function sim(
  model::Model;

  ## arguments for Cond(::Model,...)
  # constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  events_on::Vector{Pair{Symbol,Bool}} = Pair{Symbol,Bool}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  saveat::Union{Nothing,AbstractVector{T}} = nothing,
  tspan::Union{Nothing,Tuple{S,S}}=nothing,
  observables::Union{Nothing,Vector{Symbol}} = nothing,

  ## arguments for sim(::Cond,...)
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  saveat_measurements::Bool = false,
  evt_save::Tuple{Bool,Bool}=(true,true), 
  time_type=Float64,
  alg=DEFAULT_ALG, 
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs...
) where {T<:Real,S<:Real}
  condition = Cond(
    model;
    events_on = events_on,
    measurements = measurements,
    saveat = saveat,
    tspan = tspan,
    observables = observables
  )

  res = sim(
    condition;
    constants = constants,
    saveat_measurements = saveat_measurements,
    evt_save = evt_save, 
    time_type = time_type,
    alg = alg, 
    reltol = reltol,
    abstol = abstol,
    kwargs...
  )

  return res
end

### general interface for EnsembleProblem

function sim(
  condition_pairs::AbstractVector{Pair{Symbol, C}};
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  saveat_measurements::Bool = false,
  evt_save::Tuple{Bool,Bool} = (true, true),
  time_type = Float64,
  alg = DEFAULT_ALG, 
  reltol = DEFAULT_SIMULATION_RELTOL, 
  abstol = DEFAULT_SIMULATION_ABSTOL,
  output_func = default_output,
  reduction = default_reduction,
  kwargs... # other arguments for OrdinaryDiffEq.solve()
) where C<:AbstractCond

  if length(condition_pairs) == 0
    return SimResults[] # BRAKE
  end

  function prob_func(prob,i,repeat)
    build_ode_problem(last(condition_pairs[i]), constants, saveat_measurements; time_type = time_type, title = String(first(condition_pairs[i])))
  end

  prob = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func,
    output_func = output_func,
    reduction = reduction
    )

  solution = solve(prob, alg;
    trajectories = length(condition_pairs),
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
    )
  return solution.u
end

### simulate many conditions

function sim(
  conditions::AbstractVector{C};
  kwargs... # other arguments to sim(::Vector{Pair})
) where {C<:AbstractCond}
  condition_pairs = Pair{Symbol,AbstractCond}[Symbol("#$i") => cond for (i, cond) in pairs(conditions)]
  return sim(condition_pairs; kwargs...)
end

### simulate QPlatform

function sim(
  platform::QPlatform;
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

