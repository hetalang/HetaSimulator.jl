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

  return Tuple(add_event(events[ev], _events_save[ev], ev) for ev in keys(events) if events_active[ev])
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
      cb.condition(u,t,integrator) ? cb.affect!(integrator) : nothing
  end

  DiscreteCallback(
        (u,t,integrator) -> t in tstops,
        (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt_name),
        initialize = init_time_event,
        save_positions=(false,false)
  )
end

function add_event(evt::CEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  ContinuousCallback(
      evt.condition_func,
      (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt_name),
      (integrator) -> nothing,
      save_positions=(false,false)
  )
end

function add_event(evt::DEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  DiscreteCallback(
      evt.condition_func,
      (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt_name),
      save_positions=(false,false)
  )
end

function add_event(evt::StopEvent, events_save::Tuple{Bool, Bool}=(false,false), evt_name=nothing)
  DiscreteCallback(
    evt.condition_func,
    (integrator) -> evt_func_wrapper(integrator, terminate!, events_save, evt_name),
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

function reset_dt!(integrator::Sundials.AbstractSundialsIntegrator)
# not implemented 
end

function reset_dt!(integrator::SciMLBase.AbstractODEIntegrator)
  if integrator.t != integrator.sol.prob.tspan[1]  # exclude events at zero
    auto_dt_reset!(integrator)
    set_proposed_dt!(integrator, integrator.dt)
  end
end
