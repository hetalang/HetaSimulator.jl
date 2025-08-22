function build_ode_problem( # used in Scenario constructor only
  model::Model,
  tspan;
  params::NamedTuple,
  events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}} = (true,true), 
  observables_::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  save_scope::Bool = true,
  time_type::DataType = Float64,
  # experimental. kwargs to ODEFunction
  kwargs...
)
  _saveat = isnothing(saveat) ? time_type[] : time_type.(saveat)

  # init
  u0 = zeros(model.nstates)
  statics = zeros(model.nstatics)
  model.init_func(u0, statics, params)

  # !!! temporary workaround to match the order of statics and constants
  # ArrayPartition should be replaced with NamedArrayPartition when moving to Julia 1.10
  #p0 =NamedArrayPartition(statics=_p0[1:length(_p0)-length(params)], constants=collect(eltype(_p0), params))
  p0 = ArrayPartition(statics, collect(eltype(statics), params))

  # check observables
  if !isnothing(observables_)
    records_ind = indexin(observables_, records(model))
    if any((x)-> x === nothing, records_ind)
      lost_observables_ind = findall((x)-> x===nothing, records_ind)
      lost_observables = observables_[lost_observables_ind]
      error("The following observables have not been found in the model: $lost_observables")
    end
  end

  # saving setup
  utype = promote_type(eltype(u0), eltype(p0)) #change to make AD work
  merged_observables = isnothing(observables_) ? observables(model) : observables_ # use default if not set
  #=
  saved_values = SavedValues(
    LArray{utype,1,Array{utype,1},Tuple(merged_observables)}[],
    time_type[],
    save_scope ? Symbol[] : nothing
    )
  =#
  saved_values = SavedValues(
    LArray{utype,1,Array{utype,1},Tuple(merged_observables)},
    time_type
  )

  saving! = model.saving_generator(merged_observables)
  lobs = length(merged_observables)
  function saving_func(u,t,integrator)
    out = zeros(eltype(u), lobs)
    saving!(out,u,t,integrator)
    return out
  end

  scb = saving_wrapper(saving_func, saved_values; saveat=_saveat, save_scope)

  # events
  ev_on_nt = !isnothing(events_active) ? NamedTuple(events_active) : NamedTuple()
  events = active_events(model.events, merge(model.events_active, ev_on_nt), events_save)
  cbs = CallbackSet(scb, events...)

  ode_func = ODEFunction(model.ode_func; mass_matrix=model.mass_matrix, kwargs...)
  # problem setup
  return ODEProblem(
    ode_func, # ODE function
    u0, # u0
    tspan, # tspan
    p0; # constants and static
    callback = cbs # callback
  )
end

#=
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
=#

function remake_prob(scen::Scenario, params::NamedTuple; safetycopy=true)
  params_total = merge_strict(scen.parameters, params)
  remake_prob(scen.prob, scen.init_func, params_total; safetycopy)
end

function remake_prob(prob::ODEProblem, init_func::Function, params::NamedTuple; safetycopy=true)
  prob0 = safetycopy ? deepcopy(prob) : prob
  nparams = length(params)
  if nparams > 0
    #u0, dep_p0 = init_func(params)
    #p0 = NamedArrayPartition(statics=dep_p0, constants=params)
    init_func(prob0.u0, prob0.p.x[1], params)

    # update parameters
    if eltype(prob0.p.x[2]) == eltype(params) 
    # if additional params are provided
    # we shouldn't allow adding parameters, which are not in the model or scenario
    (length(prob0.p.x[2]) != nparams) && resize!(prob0.p.x[2], nparams)
      @inbounds for i in 1:nparams
        prob0.p.x[2][i] = params[i]
      end
    else # Dual ?
      prob0.p = ArrayPartition(prob0.p.x[1], params)
    end
  end
  return prob0
end

function remake_saveat(prob, saveat; tspan=prob.tspan, time_type::DataType=Float64)

  _saveat = isnothing(saveat) ? time_type[] : time_type.(saveat)

  scb_orig = prob.kwargs[:callback].discrete_callbacks[1].affect!
  utype = eltype(prob.u0)
  save_scope = scb_orig.save_scope
  #=
  saved_values = SavedValues(
    LArray{utype,1,Array{utype,1},observables(prob)}[],
    eltype(tspan)[],
    save_scope ? Symbol[] : nothing
    )
  =#
  saved_values = SavedValues(
    LArray{utype,1,Array{utype,1},observables(prob)},
    eltype(_saveat)
  )
  save_func = scb_orig.save_func
  scb_new = saving_wrapper(save_func, saved_values; saveat=_saveat, save_scope=save_scope)

  cbs = list_callbacks(prob)
  cb_set = CallbackSet(scb_new,cbs[1]...,cbs[2]...)
  remake(prob; callback=cb_set, tspan=tspan)
end

function remake_saveat(prob, measurements::Vector{M}) where M<:AbstractMeasurementPoint
  saveat = unique([dp.t for dp in measurements])
  tspan = (prob.tspan[1], eltype(prob.tspan)(maximum(saveat)))
  remake_saveat(prob, saveat; tspan)
end

function list_callbacks(prob)
  discr_cbs = prob.kwargs[:callback].discrete_callbacks
  cont_cbs = prob.kwargs[:callback].continuous_callbacks
  (discr_cbs[1:end .!=1], cont_cbs)
end

observables(prob::SciMLBase.AbstractODEProblem) = observables(
  eltype(prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values.u)
)

observables(::Type{LArray{T,N,D,Syms}}) where {T,N,D,Syms} = Syms
