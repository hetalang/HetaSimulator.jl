# single condition Monte-Carlo
function mc(
  cond::Cond,
  params::Vector{P},
  num_iter::Int;
  saveat_measurements::Bool = false, # do we need it here ?
  evt_save::Tuple{Bool,Bool}=(true,true),
  time_type=Float64,
  title=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  kwargs...
) where P<:Pair
  !has_saveat(cond) && error("Add saveat values to Condition in order to run Monte-Carlo simulations.")

  prob0 = build_ode_problem(cond, Pair{Symbol,Float64}[], saveat_measurements; time_type = time_type)
  init_func = cond.model.init_func
  t = time_type[]

  function prob_func(prob,i,repeat)
    cons_i = generate_cons(params)
    merged_cons_i = update(prob.p.constants, cons_i)

    u0, p0 = init_func(merged_cons_i)
    prob.u0 .= u0
    prob.p.constants .= merged_cons_i
    prob.p.static .= p0
    prob
  end

  function output_func(sol, i)
    i==1 && append!(t, sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values.t)
    sim = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values.vals
    (sim, false)
  end

  prob = EnsembleProblem(prob0;
    prob_func = prob_func,
    output_func = output_func,
  # reduction = reduction
  )

  solution = solve(prob, alg;
    trajectories = num_iter,
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
  )

  return MCResults(title,t,solution.u,cond)
end

function mc(
  model::QModel,
  params::Vector{P},
  num_iter::Int;

  # Cond kwargs
  events_on::Vector{Pair{Symbol,Bool}} = Pair{Symbol,Bool}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  saveat::Union{Nothing,AbstractVector{T}} = nothing,
  tspan::Union{Nothing,Tuple{S,S}}=nothing,
  observables::Union{Nothing,Vector{Symbol}} = nothing,

  # mc(c::Cond) kwargs
  kwargs...
) where {P<:Pair,T<:Real,S<:Real}

  cond = Cond(
    model;
    events_on = events_on,
    measurements = measurements,
    saveat = saveat,
    tspan = tspan,
    observables = observables
  )
  return mc(cond,params,num_iter;kwargs...)
end

# multi condition Monte-Carlo
function mc(
  cond_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractCond, P<:Pair}

  mcsol = Vector{MCResults}(undef, length(cond_pairs))
  for (i,cond) in enumerate(cond_pairs)
    mcsol[i] = mc(last(cond),params,num_iter;
      title=String(first(cond)),kwargs...)
  end
  return mcsol
end


function mc(
  platform::QPlatform,
  params::Vector{P},
  num_iter::Int;
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs...) where P<:Pair

  if isnothing(conditions)
    cond_pairs = [platform.conditions...]
  else
    cond_pairs = Pair{Symbol,AbstractCond}[]
    for cond_name in conditions
      @assert haskey(platform.conditions, cond_name) "No condition :$cond_name found in the platform."
      push!(cond_pairs, cond_name=>platform.conditions[cond_name])
    end
  end

  return mc(cond_pairs,params,num_iter;kwargs...)
end

DiffEqBase.EnsembleAnalysis.get_timestep(mc::MCResults,i) = (getindex(as_simulation(mc,j),i) for j in 1:length(mc))
DiffEqBase.EnsembleAnalysis.get_timepoint(mc::MCResults,t) = (as_simulation(mc,j)(:,t) for j in 1:length(mc))

function DiffEqBase.EnsembleAnalysis.EnsembleSummary(sim::MCResults,
  t=sim[1].t;quantiles=[0.05,0.95])

  m,v = timeseries_point_meanvar(sim,t)
  qlow = timeseries_point_quantile(sim,quantiles[1],t)
  qhigh = timeseries_point_quantile(sim,quantiles[2],t)

  trajectories = length(sim)

  EnsembleSummary{Float64,2,typeof(t),typeof(m),typeof(v),typeof(qlow),typeof(qhigh)}(t,m,v,qlow,qhigh,trajectories,0.0,true)
end


generate_cons(v::Vector{P})  where P<:Pair = [k=>generate_cons(v) for (k,v) in v]
generate_cons(v::Distribution) = rand(v)
generate_cons(v::Real) = v
