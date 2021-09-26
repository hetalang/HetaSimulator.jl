# RemoteChannel used for progress monitoring in parallel setup
const progch = RemoteChannel(()->Channel{Bool}(), 1)

"""
    mc(scenario::Condition,
      params::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single `Condition`. Returns [`MCResults`](@ref) type.

Example: `mc(scenario, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario` : simulation condition of type [`HetaSimulator.Condition`](@ref)
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
  scenario::Condition,
  params::Vector{P},
  num_iter::Int;
  verbose=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs...
) where P<:Pair

  prob0 = scenario.prob
  init_func = scenario.init_func
  params_nt = NamedTuple(params)

  progress_on = true #(parallel_type == EnsembleSerial()) # tmp fix
  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled = progress_on)

  function prob_func(prob,i,repeat)
    verbose && println("Processing iteration $i")
    parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true)
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

  if parallel_type != EnsembleDistributed()
    solution = solve(prob, alg, parallel_type;
      trajectories = num_iter,
      reltol = reltol,
      abstol = abstol,
      save_start = false,
      save_end = false,
      save_everystep = false,
      kwargs...
    )
  else
    @sync begin
      @async while take!(progch)
        next!(p)
      end
      @async begin
        solution = solve(prob, alg, parallel_type;
          trajectories = num_iter,
          reltol = reltol,
          abstol = abstol,
          save_start = false,
          save_end = false,
          save_everystep = false,
          kwargs...
        )
        put!(progch, false)
      end
    end
  end

  return MCResults(solution.u, !has_saveat(scenario), scenario)
end

"""
    mc(scenario::Condition,
      params::DataFrame,
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `scenario`. Returns [`MCResults`](@ref) type.

Example: `mc(scn1, DataFrame(k2=rand(3),k3=rand(3)), 1000)`

Arguments:

- `scenario` : simulation scenario of type [`HetaSimulator.Condition`](@ref)
- `params` : DataFrame with pre-generated parameters.
- `num_iter` : number of Monte-Carlo iterations 
- kwargs : other solver related arguments supported by `mc(scenario::Condition, params::Vector, num_iter::Int64)`
"""
function mc(
  scenario::Condition,
  params::DataFrame;
  num_iter::Int= size(params)[1],
  kwargs...
) 
  cons = keys(parameters(scenario))
  params_pairs = Pair[]
  

  for pstr in names(params)
    psym = Symbol(pstr)
    @assert (psym in cons) "$psym is not found in models constants."   
    push!(params_pairs, psym=>params[!,psym])
  end

  return mc(scenario, params_pairs, num_iter; kwargs...)
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
- kwargs : other solver related arguments supported by `mc(scenario::Condition, params::Vector, num_iter::Int64)`
"""
function mc(
  model::Model,
  params::Vector{P},
  num_iter::Int;

  ## arguments for Condition(::Model,...)
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

  scenario = Condition(
    model; measurements,
    events_active, events_save, observables, saveat, tspan, save_scope, time_type)

  return mc(scenario, params, num_iter; kwargs...)
end

# multi condition Monte-Carlo

"""
    mc(scenario_pairs::Vector{<:Pair},
      params::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single condition `scenario`. Returns `Vector{MCResults}` type.

Example: `mc([:c1=>scn1,:c2=>scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of pairs containing names and conditions of type [`HetaSimulator.Condition`](@ref)
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
  scenario_pairs::Vector{CP},
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
  lc = length(scenario_pairs)
  iter = collect(Iterators.product(1:lp,1:lc))


  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled=true)

  function prob_func(prob,i,repeat)
    iter_i = iter[i]
    verbose && println("Processing condition $(iter_i[2]) iteration $(iter_i[1])")
    parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true)
    prob_i = last(scenario_pairs[iter_i[2]]).prob
    init_i = last(scenario_pairs[iter_i[2]]).init_func
    update_init_values(prob_i, init_i, params_pregenerated[iter_i[1]])
  end

  function output_func(sol, i)
    sim = build_results(sol)
    (sim, false)
  end

  prob = EnsembleProblem(last(scenario_pairs[1]).prob;
    prob_func = prob_func,
    output_func = output_func,
    #reduction = reduction_func
  )

  if parallel_type != EnsembleDistributed()
    solution = solve(prob, alg, parallel_type;
      trajectories = lp*lc,
      reltol = reltol,
      abstol = abstol,
      save_start = false,
      save_end = false,
      save_everystep = false,
      kwargs...
    )
  else
    @sync begin
      @async while take!(progch)
        next!(p)
      end
      @async begin
        solution = solve(prob, alg, parallel_type;
          trajectories = lp*lc,
          reltol = reltol,
          abstol = abstol,
          save_start = false,
          save_end = false,
          save_everystep = false,
          kwargs...
        )
        put!(progch, false)
      end
    end
  end

  ret = Vector{Pair{Symbol,MCResults}}(undef, lc)

  for i in 1:lc
    ret[i] = first(scenario_pairs[i]) => 
      MCResults(solution.u[lp*(i-1)+1:i*lp], false, last(scenario_pairs[i]))
  end
  return ret
end

"""
    mc(scenario_pairs::Vector{<:AbstractCond},
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `scenario`. Returns `Vector{MCResults}` type.

Example: `mc([scn1,scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of scenarios of type [`HetaSimulator.Condition`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(scenario_pairs::Vector{<:Pair}, params::Vector, num_iter::Int64)`
"""
function mc(
  scenario_pairs::Vector{C},
  params::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractCond, P<:Pair}

  scenario_pairs = [(Symbol("_$i") => scn) for (i, scn) in pairs(scenario_pairs)]
  return mc(scenario_pairs, params, num_iter; kwargs...)
end

"""
    mc(platform::Platform, 
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single condition `scenario`. Returns `Vector{MCResults}` type.

Example: `mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(scenario_pairs::Vector{<:Pair}, params::Vector, num_iter::Int64)`
"""
function mc(
  platform::Platform,
  params::Vector{P},
  num_iter::Int;
  conditions::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs...) where P<:Pair

  if isnothing(conditions)
    scenario_pairs = [platform.conditions...]
  else
    scenario_pairs = Pair{Symbol,AbstractCond}[]
    for scn_name in conditions
      @assert haskey(platform.conditions, scn_name) "No condition :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.conditions[scn_name])
    end
  end

  return mc(scenario_pairs,params,num_iter;kwargs...)
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

"""
    read_mcvecs(filepath::String)

Read table with pre-generated parameters for Monte-Carlo simulations. Typically used for virtual patients simulations

Arguments:

- `filepath`: path to the file with pre-generated parameters
"""
read_mcvecs(filepath::String) = DataFrame(CSV.File(filepath))
