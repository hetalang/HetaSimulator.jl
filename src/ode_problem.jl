function build_ode_problem(
  model::Model;
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  events_on::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Tuple{Bool,Bool}=(true,true), 
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  tspan::Union{Nothing,Tuple} = nothing,
  save_scope::Bool=true,
  time_type::DataType=Float64
)
  # saveat and tspan
  _saveat, _tspan = saveat_tspan(saveat, tspan, time_type)

  # initial values and params
  init_func = model.init_func
  u0, params = init_values(init_func, update(model.constants, constants))

  # saving setup
  utype = eltype(u0)
  saved_values = SavedValues(
    VectorOfArray(LArray{utype,1,Array{utype,1},Tuple(observables)}[]),
    time_type[],
    save_scope ? Symbol[] : nothing
    )
  _observables = isnothing(observables) ? model.observables : observables # use default if not set
  saving_func = model.saving_generator(_observables)
  scb = saving_wrapper(saving_func, saved_values; saveat=_saveat, save_scope)

  # events
  events = active_events(model.events, update(events_on(model), events_on), events_save)
  cbs = CallbackSet(scb, events...)

  # problem setup
  return ODEProblem(
    model.ode, # ODE function
    u0, # u0
    _tspan, # tspan
    params; # constants and static
    callback = cbs # callback
  )
end

function saveat_tspan(saveat, tspan, time_type)

  if !isnothing(saveat) && !isempty(saveat)
    _saveat = collect_saveat(saveat)
    _tspan = (zero(time_type), time_type(maximum(_saveat)))
  elseif !isnothing(tspan)
    _saveat = time_type[]
    _tspan = (zero(time_type), time_type(last(tspan))) # tspan should start from zero?
  else
    error("Please, provide either `saveat` or `tspan` value.")
  end
  return (_saveat, _tspan)
end


collect_saveat(saveat::Tuple) = Float64[]
collect_saveat(saveat::Vector{S}) where S<:Real = Float64.(saveat)
collect_saveat(saveat::AbstractRange{S}) where S<:Real = Float64.(saveat)

function init_values(init_func, constants)
  u0, p0 = init_func(constants)
  return (u0,Params{typeof(_cons),typeof(_p0)}(constants, p0))
end
