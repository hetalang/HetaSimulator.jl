
const DEFAULT_SIMULATION_RELTOL=1e-3
const DEFAULT_SIMULATION_ABSTOL=1e-6
const DEFAULT_ALG = AutoTsit5(Rosenbrock23())

const EMPTY_PROBLEM = ODEProblem(() -> nothing, [0.0], (0.,1.))

### simulate condition

function sim(
  condition::Cond; 
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  saveat_measurements::Bool = false,
  evt_save::Tuple{Bool,Bool}=(true,true),
  time_type=Float64,
  termination=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs...
)
  prob = build_ode_problem(condition, constants, saveat_measurements; time_type = time_type, termination=termination)

  sol = solve(prob, alg; reltol = reltol, abstol = abstol,
    save_start = false, save_end = false, save_everystep = false, kwargs...)

  return sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
end

### simulate QModel

function sim(
  model::QModel;

  ## arguments for Cond(::QModel,...)
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

function build_ode_problem(
  condition::Cond,
  cons::Vector{Pair{Symbol,Float64}},
  saveat_measurements::Bool;
  evt_save::Tuple{Bool,Bool} = (true, true),
  time_type = Float64,
  termination=nothing,
  title::Union{String,Nothing} = nothing
  # params - fitting
)
  model = condition.model

  #= check if default alg can solve the prob
  integrator = init(prob, DEFAULT_ALG)
  step!(integrator)
  ret = check_error(integrator)
  ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."
  =#

  ### Cond part
  # saveat and tspan
  if saveat_measurements
    _saveat = unique([dp.t for dp in condition.measurements])
    _tspan = (zero(time_type), time_type(maximum(_saveat)))
  elseif condition.saveat !== nothing && !isempty(condition.saveat)
    _saveat = collect_saveat(condition.saveat)
    _tspan = (zero(time_type), time_type(maximum(_saveat)))
  elseif condition.tspan !== nothing
    _saveat = time_type[]
    _tspan = (zero(time_type), time_type(last(condition.tspan))) # tspan should begin from zero?
  else
    error("Please, provide either `saveat` or `tspan` value.")
  end

  ### Merging
  merged_cons0 = update(model.constants, condition.constants)
  _constants = update(merged_cons0, cons)
  
  # Model part
  # future _u0 @LArray u0 (names_[:variables]...,)
  # future _p0 @LArray p0 (names_[:parameters]...,)
  _ode = model.ode
  _u0, _p0 = model.init_func(_constants)
  _params = Params{typeof(_constants),typeof(_p0)}(_constants, _p0)

  # saving cb
  U = eltype(_u0)
  sim = SimResults(
    title,
    _constants,
    time_type[],
    LabelledArrays.LArray{U,1,Array{U,1},Tuple(condition.observables)}[],
    Symbol[], 
    condition
    )

  # events
  cbs = []
  push!(cbs, SavingEventWrapper(condition.saving, sim; saveat = _saveat))
  !isnothing(termination) && push!(cbs, DiscreteCallback(termination, terminate!; save_positions=(false,false)))

  active_events_names = update(events(model), events(condition)) # evts_dict
  active_events = [push!(cbs, add_event(evt, _constants; evt_save = evt_save)) for evt in model.events if active_events_names[evt.name]]
  evts = CallbackSet(cbs...)

  prob = ODEProblem(
    _ode, # ODE function
    _u0, # u0
    _tspan, # tspan
    _params; # const and static
    callback = evts # callback
    # mass_matrix
    )

  return prob
end

function default_output(sol,i)
  sim = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
  sim,false
end

default_reduction(u,batch,I) = (append!(u,batch),false)

