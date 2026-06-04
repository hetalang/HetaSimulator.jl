active_events(events::NamedTuple, events_active::NamedTuple, events_save::Tuple) =
  active_events(events, events_active, NamedTuple{keys(events)}(fill(events_save,length(events))))

active_events(events::NamedTuple, events_active::NamedTuple, events_save::Vector{Pair{Symbol, Tuple{Bool, Bool}}}) =
  active_events(events, events_active, NamedTuple(events_save))

function active_events(events::NamedTuple, events_active::NamedTuple, events_save::NamedTuple)
  ev_names = keys((events))
  for k in (keys(events_active)..., keys(events_save)...)
    @assert k in ev_names "Event $k not found."
  end
  _events_save = merge(NamedTuple{ev_names}(fill((false,false), length(events))), events_save)

  callbacks = Tuple(
    add_event(events[ev], _events_save[ev], ev)
    for ev in keys(events)
    if events_active[ev] && !(events[ev] isa CEvent)
  )
  c_events = Tuple(
    ev => events[ev]
    for ev in keys(events)
    if events_active[ev] && events[ev] isa CEvent
  )
  c_events_save = Tuple(_events_save[first(evt)] for evt in c_events)
  c_callback = add_continuous_events(c_events, c_events_save)

  isnothing(c_callback) ? callbacks : (callbacks..., c_callback)
end

function add_event(evt::TimeEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  tstops = Float64[]
  #scn_func(u, t, integrator) = t in tstops

  function init_time_event(cb,u,t,integrator)
      ts = evt.condition_func(integrator.sol.prob.p.x[2], integrator.sol.prob.tspan)
      append!(tstops, _to_float.(ts)) # fix for Dual numbers
      tf = integrator.sol.prob.tspan[2]
      [add_tstop!(integrator, tstop) for tstop in tstops if tstop <= tf]
      #[add_tstop!(integrator, tstop) for tstop in tstops]
      if cb.condition(u, t, integrator)
        cb.affect!(integrator)
        derivative_discontinuity!(integrator, true)
      end
    return nothing
  end

  DiscreteCallback(
        (u,t,integrator) -> t in tstops,
        (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt_name);
        initialize = init_time_event,
        save_positions=(false,false)
  )
end

function add_event(evt::CEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  add_continuous_events((evt_name => evt,), (events_save,))
end

function add_continuous_events(events::Tuple, events_save::Tuple)
  isempty(events) && return nothing

  ev_names = first.(events)
  evts = last.(events)
  len = length(evts)

  function condition(out, u, t, integrator)

    @inbounds for i in 1:len
      out[i] = evts[i].condition_func(u, t, integrator)
    end
    return nothing
  end

  function affect!(integrator, simultaneous_events)
    for event_idx in eachindex(simultaneous_events)
      s = simultaneous_events[event_idx]
      #=
      | `0`  | condition did not trigger this step |
      | `-1` | upcrossing (condition went from negative to positive) |
      | `+1` | downcrossing (condition went from positive to negative) |
      =#
      if s == 1  
        evt = evts[event_idx]
        evt_func_wrapper(integrator, evt.affect_func, events_save[event_idx], ev_names[event_idx])
      end
    end
  end

  function init_continuous_events(cb, u, t, integrator)
    simultaneous_events = zeros(Int8, len)

    @inbounds for i in 1:len
      evt = evts[i]
      val = evt.condition_func(u, t, integrator)

      if evt.atStart && val >= 0 #abs(val) <= cb.abstol
        simultaneous_events[i] = Int8(1)
      end
    end

    if any(isone, simultaneous_events)
      ensure_saving_initialized!(integrator)
      cb.affect!(integrator, simultaneous_events)
      derivative_discontinuity!(integrator, true)
    end

    return nothing
  end

  VectorContinuousCallback(
      condition,
      affect!,
      len;
      initialize = init_continuous_events,
      save_positions=(false,false)
  )
end

function add_event(evt::DEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  function init_time_event(cb,u,t,integrator) 
    if evt.atStart && cb.condition(u, t, integrator)
      cb.affect!(integrator)
      derivative_discontinuity!(integrator, true)
    end
    return nothing
  end

  DiscreteCallback(
      evt.condition_func,
      (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt_name);
      initialize = init_time_event,
      save_positions=(false,false)
  )
end

function add_event(evt::StopEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)

  function init_time_event(cb,u,t,integrator)
    if evt.atStart && cb.condition(u,t,integrator)
      cb.affect!(integrator)
      derivative_discontinuity!(integrator, true)
    end
    return nothing
  end
    
  DiscreteCallback(
    evt.condition_func,
    (integrator) -> evt_func_wrapper(integrator, terminate!, events_save, evt_name);
    initialize = init_time_event,
    save_positions=(false,false)
  )
end

function evt_func_wrapper(integrator, evt_func, events_save, evt_name)
  # check saveat values before applying a callback
  save_after_step!(integrator)
  # save timepoint before and after applying a callback
  first(events_save) && save_timepoint!(integrator, :ode_) #affect_func!(integrator, true)
  evt_func(integrator)
  last(events_save) && save_timepoint!(integrator, evt_name)
  reset_dt!(integrator)
end

function reset_dt!(integrator::SciMLBase.AbstractODEIntegrator)
  if integrator.t != integrator.sol.prob.tspan[1]  # exclude events at zero
    auto_dt_reset!(integrator)
    set_proposed_dt!(integrator, integrator.dt)
  end
end

function reset_dt!(integrator)
# not implemented for other integrators, but should be added if needed
end
