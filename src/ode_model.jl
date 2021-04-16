
# Func name should be changed - now it reflects heta-compiler 
function Model(
  init_func,
  ode,
  events,
  saving_generator,
  cons,
  observables;
  title::String = "test",
  free_constants::NamedTuple = NamedTuple(),
  default_events::Vector{Pair{Symbol,Bool}} = Pair{Symbol,Bool}[],
  el_type::DataType = Float64,
  kwargs...
) 
  print("Loading model... ")

  # TEMP solution
  _constants = LVector(cons)
  #evts_names = isempty(events) ? Pair{Symbol}[] : [evt.name for evt in events]
  events_on = default_events #@LArray fill(true, length(evts_names)) tuple(evts_names...) # ugly

  # Should we (1) store prob in Model, (2) store in Cond (3) nowhere
  ### fake run 
  _u0, _p0 = init_func(_constants)
  _params = Params(_constants, _p0)
  prob = ODEProblem(ode, _u0, (0.,1.), _params)

  # check if default alg can solve the prob
  integrator = init(prob, DEFAULT_ALG)
  step!(integrator)
  ret = check_error(integrator)
  ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."

  ###

  println("OK!")

  return QModel(init_func, ode, events, saving_generator, observables, _constants, events_on)
end


