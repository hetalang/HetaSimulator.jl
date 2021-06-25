# single condition Monte-Carlo
function mc(
  cond::Cond,
  params::Vector{P},
  num_iter::Int;
  verbose=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs...
) where P<:Pair

  prob0 = cond.prob
  init_func = cond.init_func
  params_nt = NamedTuple(params)

  function prob_func(prob,i,repeat)
    verbose && println("Processing iteration $i")

    update_init_values(prob, init_func, generate_cons(params_nt,i))
  end

  function output_func(sol, i)
    sim = build_results(sol,cond)
    (sim, false)
  end

  prob = EnsembleProblem(prob0;
    prob_func = prob_func,
    output_func = output_func,
    #reduction = reduction_func
  )

  solution = solve(prob, alg, parallel_type;
    trajectories = num_iter,
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
  )

  return MCResults(solution.u, !has_saveat(cond), cond)
end

function mc(
  cond::Cond,
  params::DataFrame;
  num_iter::Int= size(params)[1],
  kwargs...
) 
  cons = keys(parameters(cond))
  params_pairs = Pair[]
  

  for pstr in names(params)
    psym = Symbol(pstr)
    @assert (psym in cons) "$psym is not found in models constants."   
    push!(params_pairs, psym=>params[!,psym])
  end

  return mc(cond,params_pairs,num_iter;kwargs...)
end

#=FIXME
function mc(
  model::Model,
  params::Vector{P},
  num_iter::Int;

  # Cond kwargs
  events_active::Vector{Pair{Symbol,Bool}} = Pair{Symbol,Bool}[],
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  saveat::Union{Nothing,AbstractVector{T}} = nothing,
  tspan::Union{Nothing,Tuple{S,S}}=nothing,
  observables::Union{Nothing,Vector{Symbol}} = nothing,

  # mc(c::Cond) kwargs
  kwargs...
) where {P<:Pair,T<:Real,S<:Real}

  cond = Cond(
    model;
    events_active = events_active,
    measurements = measurements,
    saveat = saveat,
    tspan = tspan,
    observables = observables
  )
  return mc(cond,params,num_iter;kwargs...)
end
=#
# multi condition Monte-Carlo
function mc(
  cond_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{P},
  num_iter::Int;
  verbose=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs...
) where {C<:AbstractCond, P<:Pair}
  
  params_nt = NamedTuple(params)
  params_pregenerated = [generate_cons(params_nt,i) for i in 1:num_iter]
  lp = length(params_pregenerated)
  lc = length(cond_pairs)
  iter = collect(Iterators.product(1:lp,1:lc))

  function prob_func(prob,i,repeat)
    iter_i = iter[i]
    verbose && println("Processing condition $(iter_i[2]) iteration $(iter_i[1])")
    prob_i = last(cond_pairs[iter_i[2]]).prob
    init_i = last(cond_pairs[iter_i[2]]).init_func
    update_init_values(prob_i, init_i, params_pregenerated[iter_i[1]])
  end

  function output_func(sol, i)
    sim = build_results(sol,last(cond_pairs[iter[i][2]]))
    (sim, false)
  end

  prob = EnsembleProblem(last(cond_pairs[1]).prob;
    prob_func = prob_func,
    output_func = output_func,
    #reduction = reduction_func
  )

  solution = solve(prob, alg, parallel_type;
    trajectories = lp*lc,
    reltol = reltol,
    abstol = abstol,
    save_start = false,
    save_end = false,
    save_everystep = false,
    kwargs...
  )

  return MCResults(solution.u, false, nothing)
end
#=
function mc(
  cond_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractCond, P<:Pair}

  mcsol = Vector{MCResults}(undef, length(cond_pairs))
  for (i,cond) in enumerate(cond_pairs)
    mcsol[i] = mc(last(cond),params,num_iter;
      kwargs...)
  end
  return [first(k)=> v for (k,v) in zip(cond_pairs,mcsol)]
end
=#
function mc(
  platform::Platform,
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

#=FIXME
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
=#

generate_cons(vp::Vector{P},i)  where P<:Pair = NamedTuple([k=>generate_cons(v,i) for (k,v) in vp])
generate_cons(nt::NamedTuple,i) = NamedTuple{keys(nt)}([generate_cons(v,i) for v in nt])
generate_cons(v::Distribution,i) = rand(v)
generate_cons(v::Real,i) = v
generate_cons(v::Vector{R},i) where R<:Float64 = v[i]

read_mcvecs(filepath::String) = DataFrame(CSV.File(filepath))
