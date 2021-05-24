active_events(events, events_on, events_save::Tuple) =
  active_events(events, events_on, fill(events_save, length(events)))

active_events(events, events_on, events_save::Vector{Tuple}) =
  Tuple(add_event(evt; events_save) for evt in events if events_on)

function add_event(evt::TimeEvent; events_save::Tuple{Bool, Bool}=(true,true))
  tstops = Float64[]
  #cond_func(u, t, integrator) = t in tstops

  function init_time_event(cb,u,t,integrator)
      append!(tstops, evt.condition_func(integrator.sol.prob.p.constants, integrator.sol.prob.tspan))
      #tf = integrator.sol.prob.tspan[2]
      #[add_tstop!(integrator, tstop) for tstop in tstops if tstop <= tf]
      [add_tstop!(integrator, tstop) for tstop in tstops]
      cb.condition(u,t,integrator) ? cb.affect!(integrator) : nothing
  end

  DiscreteCallback(
        (u,t,integrator) -> t in tstops,
        (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt.name),
        initialize = init_time_event,
        save_positions=(false,false)
  )
end

function add_event(evt::CEvent; events_save::Tuple{Bool, Bool}=(true,true))
  ContinuousCallback(
      evt.condition_func,
      (integrator) -> evt_func_wrapper(integrator, evt.affect_func, events_save, evt.name),
      (integrator) -> nothing,
      save_positions=(false,false)
  )
end

function add_event(evt::StopEvent; kwargs...)
  DiscreteCallback(
    evt.condition_func,
    terminate!,
    save_positions=(false,false)
  )
end

function evt_func_wrapper(integrator, evt_func, events_save, evt_name)
  affect_func! = integrator.opts.callback.discrete_callbacks[1].affect!
 # affect_func!(integrator) #produces wrong results in Sundials

  first(events_save) && save_position(integrator, :ode_) #affect_func!(integrator, true)
  evt_func(integrator)
  last(events_save) && save_position(integrator, evt_name)
  reset_dt!(integrator)
end

function reset_dt!(integrator::Sundials.AbstractSundialsIntegrator)
# not implemented 
end

function reset_dt!(integrator::DiffEqBase.AbstractODEIntegrator)
  auto_dt_reset!(integrator)
  set_proposed_dt!(integrator, integrator.dt)
end

function save_position(integrator::DiffEqBase.AbstractODEIntegrator, scope=:ode_)

  affect! = integrator.opts.callback.discrete_callbacks[1].affect!
  affect!.saveiter += 1
  copyat_or_push!(affect!.saved_values.t, affect!.saveiter, integrator.t)
  copyat_or_push!(affect!.saved_values.scope, affect!.saveiter, scope, Val{false})
  copyat_or_push!(affect!.saved_values.vals, affect!.saveiter, affect!.save_func(integrator.u, integrator.t, integrator),Val{false})
end
