# single condition Monte-Carlo

"""
    mc(cond::Cond,
      params::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single condition `cond`. Returns [`MCResults`](@ref) type.
Example: `mc(cond, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `cond` : simulation condition of type [`Cond`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
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

  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50)

  function prob_func(prob,i,repeat)
    verbose && println("Processing iteration $i")
    next!(p)
    update_init_values(prob, init_func, generate_cons(params_nt,i))
  end

  function output_func(sol, i)
    sim = build_results(sol)
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

"""
    mc(cond::Cond,
      params::DataFrame,
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `cond`. Returns [`MCResults`](@ref) type.
Example: `mc(cond1, DataFrame(k2=rand(3),k3=rand(3)), 1000)`

Arguments:

- `cond` : simulation condition of type [`Cond`](@ref)
- `params` : DataFrame with pre-generated parameters.
- `num_iter` : number of Monte-Carlo iterations 
- kwargs : other solver related arguments supported by `mc(cond::Cond, params::Vector, num_iter::Int64)`
"""
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

"""
    mc(model::Model,
      params::Vector{<:Pair},
      num_iter::Int64;
      measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
      events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
      events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
      observables::Union{Nothing,Vector{Symbol}} = nothing,
      saveat::Union{Nothing,AbstractVector} = nothing,
      tspan::Union{Nothing,Tuple} = nothing,
      save_scope::Bool=false,
      time_type::DataType=Float64,
      kwargs...
    )

Run Monte-Carlo simulations with `Model`. Returns [`MCResults`](@ref) type.
Example: `mc(model, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `model` : model of type [`Model`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `measurements` : `Vector` of measurements. Default is empty vector 
- `events_active` : `Vector` of `Pair`s containing events' names and true/false values. Overwrites default model's values. Default is empty vector 
- `events_save` : `Tuple` or `Vector{Tuple}` marking whether to save solution before and after event. Default is `(true,true)` for all events
- `observables` : names of output observables. Overwrites default model's values. Default is empty vector
- `saveat` : time points, where solution should be saved. Default `nothing` values stands for saving solution at timepoints reached by the solver 
- `tspan` : time span for the ODE problem
- `save_scope` : should scope be saved together with solution. Default is `false`
- kwargs : other solver related arguments supported by `mc(cond::Cond, params::Vector, num_iter::Int64)`
"""
function mc(
  model::Model,
  params::Vector{P},
  num_iter::Int;

  ## arguments for Cond(::Model,...)
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
  events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}}=(true,true), 
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  saveat::Union{Nothing,AbstractVector} = nothing,
  tspan::Union{Nothing,Tuple} = nothing,
  save_scope::Bool=false,
  time_type::DataType=Float64,

  kwargs...
) where P<:Pair

  cond = Cond(
    model; measurements,
    events_active, events_save, observables, saveat, tspan, save_scope, time_type)

  return mc(cond,params,num_iter;kwargs...)
end

# multi condition Monte-Carlo

"""
    mc(cond_pairs::Vector{<:Pair},
      params::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single condition `cond`. Returns `Vector{MCResults}` type.
Example: `mc([:c1=>cond1,:c2=>cond2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `cond_pairs` : vector of pairs containing names and conditions of type [`Cond`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function mc(
  cond_pairs::Vector{CP},
  params::Vector{PP},
  num_iter::Int;
  verbose=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs...
) where {CP<:Pair, PP<:Pair}
  
  params_nt = NamedTuple(params)
  params_pregenerated = [generate_cons(params_nt,i) for i in 1:num_iter]
  lp = length(params_pregenerated)
  lc = length(cond_pairs)
  iter = collect(Iterators.product(1:lp,1:lc))

  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50)

  function prob_func(prob,i,repeat)
    iter_i = iter[i]
    verbose && println("Processing condition $(iter_i[2]) iteration $(iter_i[1])")
    next!(p)
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

  ret = Vector{Pair{Symbol,MCResults}}(undef, lc)
  for i in 1:lc
    ret[i] = first(cond_pairs[iter[i][2]]) => 
      MCResults(solution.u[lp*(i-1)+1:i*lp], false, last(cond_pairs[iter[i][2]]))
  end
  return ret
end

"""
    mc(conds::Vector{<:AbstractCond},
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `cond`. Returns `Vector{MCResults}` type.
Example: `mc([cond1,cond2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `cond_pairs` : vector of conditions of type [`Cond`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(cond_pairs::Vector{<:Pair}, params::Vector, num_iter::Int64)`
"""
function mc(
  conds::Vector{C},
  params::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractCond, P<:Pair}

  condition_pairs = [(Symbol("_$i")=>cond) for (i, cond) in pairs(conds)]
  return mc(condition_pairs, params, num_iter; kwargs...)
end

"""
    mc(platform::Platform, 
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `cond`. Returns `Vector{MCResults}` type.
Example: `mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(cond_pairs::Vector{<:Pair}, params::Vector, num_iter::Int64)`
"""
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