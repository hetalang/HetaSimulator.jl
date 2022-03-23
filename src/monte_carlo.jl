# RemoteChannel used for progress monitoring in parallel setup
const progch = RemoteChannel(()->Channel{Bool}(), 1)

# as in SciMLBase
DEFAULT_REDUCTION(u,data,I) = append!(u, data), false
DEFAULT_OUTPUT(sol,i) = sol

"""
    mc(scenario::Scenario,
      params::Vector{<:Pair},
      num_iter::Int;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      saveat=Float64[],
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns [`MCResult`](@ref) type.

Example: `mc(scenario, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario` : simulation scenario of type [`Scenario`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `progress_bar` : show progress bar. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `saveat` : time points to save the solution at. Default is solver stepwise saving
- `output_func` : the function determines what is saved from the solution to the output array. Defaults to saving the solution itself
- `reduction_func` : this function determines how to reduce the data in each batch. Defaults to appending the data from the batches
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function mc(
  scenario::Scenario,
  params::Vector{P},
  num_iter::Int;
  verbose=false,
  progress_bar=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  saveat=Float64[],
  output_func=DEFAULT_OUTPUT,
  reduction_func = DEFAULT_REDUCTION,
  parallel_type=EnsembleSerial(),
  kwargs...
) where P<:Pair

  prob0 = scenario.prob
  init_func = scenario.init_func
  params_nt = NamedTuple(params)

  #(parallel_type == EnsembleSerial()) # tmp fix
  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled = progress_bar)
  
  function prob_func(prob,i,repeat)
    verbose && println("Processing iteration $i")
    progress_bar && (parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true))
    prob_i = !isempty(saveat) ? remake_saveat(prob, saveat) : prob
    update_init_values(prob_i, init_func, generate_cons(params_nt,i))
  end

  params_names = collect(keys(params_nt))
  function _output(sol, i)
    sim = build_results(sol, params_names)
    (output_func(sim, i), false)
  end

  prob = EnsembleProblem(prob0;
    prob_func = prob_func,
    output_func = _output,
    reduction = reduction_func
  )

  if progress_bar && (parallel_type == EnsembleDistributed())
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
  else
    solution = solve(prob, alg, parallel_type;
      trajectories = num_iter,
      reltol = reltol,
      abstol = abstol,
      save_start = false,
      save_end = false,
      save_everystep = false,
      kwargs...
    )
  end

  return MCResult(solution.u, !isempty(saveat), scenario)
end

"""
    mc(scenario::Scenario,
      params::DataFrame,
      num_iter::Int;
      kwargs...
    )

Run Monte-Carlo simulations with single scenario `Scenario`. Returns [`MCResult`](@ref) type.

Example: `mc(scn1, DataFrame(k2=rand(3),k3=rand(3)), 1000)`

Arguments:

- `scenario` : simulation scenario of type [`Scenario`](@ref)
- `params` : DataFrame with pre-generated parameters.
- `num_iter` : number of Monte-Carlo iterations 
- kwargs : other solver related arguments supported by `mc(scenario::Scenario, params::Vector, num_iter::Int64)`
"""
function mc(
  scenario::Union{Scenario, Vector{Pair{Symbol,Scenario}}, Vector{Scenario}, Platform},
  params::DataFrame;
  num_iter::Int = size(params)[1],
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

# multi scenario Monte-Carlo

"""
    mc(scenario_pairs::Vector{<:Pair},
      params::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      saveat=Float64[],
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns `Vector{MCResult}` type.

Example: `mc([:c1=>scn1,:c2=>scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `progress_bar` : show progress bar. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `saveat` : time points to save the solution at. Default is solver stepwise saving
- `output_func` : the function determines what is saved from the solution to the output array. Defaults to saving the solution itself
- `reduction_func` : this function determines how to reduce the data in each batch. Defaults to appending the data from the batches
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function mc(
  scenario_pairs::Vector{CP},
  params::Vector{PP},
  num_iter::Int;
  verbose=false,
  progress_bar=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  saveat=Float64[],
  output_func=DEFAULT_OUTPUT,
  reduction_func = DEFAULT_REDUCTION,
  parallel_type=EnsembleSerial(),
  kwargs...
) where {CP<:Pair, PP<:Pair}

  params_nt = NamedTuple(params)
  params_pregenerated = [generate_cons(params_nt,i) for i in 1:num_iter]
  lp = length(params_pregenerated)
  lc = length(scenario_pairs)
  iter = collect(Iterators.product(1:lp,1:lc))


  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled=progress_bar)

  function prob_func(prob,i,repeat)
    iter_i = iter[i]
    verbose && println("Processing scenario $(iter_i[2]) iteration $(iter_i[1])")
    progress_bar && (parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true))
    prob_i = last(scenario_pairs[iter_i[2]]).prob
    prob_i = !isempty(saveat) ? remake_saveat(prob_i, saveat) : prob_i 
    init_i = last(scenario_pairs[iter_i[2]]).init_func
    update_init_values(prob_i, init_i, params_pregenerated[iter_i[1]])
  end

  params_names = collect(keys(params_nt))
  function _output(sol, i)
    sim = build_results(sol, params_names)
    (output_func(sim, i), false)
  end

  prob = EnsembleProblem(last(scenario_pairs[1]).prob;
    prob_func = prob_func,
    output_func = _output,
    reduction = reduction_func
  )

  if progress_bar && (parallel_type == EnsembleDistributed())
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
  else
    solution = solve(prob, alg, parallel_type;
      trajectories = lp*lc,
      reltol = reltol,
      abstol = abstol,
      save_start = false,
      save_end = false,
      save_everystep = false,
      kwargs...
    )
  end

  ret = Vector{Pair{Symbol,MCResult}}(undef, lc)

  for i in 1:lc
    ret[i] = first(scenario_pairs[i]) => 
      MCResult(solution.u[lp*(i-1)+1:i*lp], !isempty(saveat), last(scenario_pairs[i]))
  end
  return ret
end

"""
    mc(scenario_pairs::Vector{<:AbstractScenario},
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single scenario. Returns `Vector{MCResult}` type.

Example: `mc([scn1,scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of scenarios of type [`Scenario`](@ref)
- `params` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(scenario_pairs::Vector{<:Pair}, params::Vector, num_iter::Int64)`
"""
function mc(
  scenario_pairs::Vector{C},
  params::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractScenario, P<:Pair}

  scenario_pairs = [(Symbol("_$i") => scn) for (i, scn) in pairs(scenario_pairs)]
  return mc(scenario_pairs, params, num_iter; kwargs...)
end

"""
    mc(platform::Platform, 
      params::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns `Vector{MCResult}` type.

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
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing,
  kwargs...) where P<:Pair

  if isnothing(scenarios)
    scenario_pairs = [platform.scenarios...]
  else
    scenario_pairs = Pair{Symbol,AbstractScenario}[]
    for scn_name in scenarios
      @assert haskey(platform.scenarios, scn_name) "No scenario :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.scenarios[scn_name])
    end
  end

  return mc(scenario_pairs,params,num_iter;kwargs...)
end

########################################## Statistics ######################################################

# currently median and quantile don't output LVector

function DiffEqBase.EnsembleAnalysis.get_timestep(mcr::MCResult, i) 
  @assert has_saveat(mcr) "Solution doesn't contain single time vector, default statistics are not available."

  return (getindex(mcr[j],i) for j in 1:length(mcr))
end

# XXX: maybe it's a good idea to add: vars::AbstractVector{Symbol}=observables(mcr)
function DiffEqBase.EnsembleAnalysis.get_timepoint(mcr::MCResult, t)
  @assert has_saveat(mcr) "Solution doesn't contain single time vector, default statistics are not available."

  # indexes = indexin(vars, observables(mcr))

  res = (mcr[j](t) for j in 1:length(mcr)) # mcr[1](t) # is a LabelledArray
  
  return res
end

function DiffEqBase.EnsembleAnalysis.EnsembleSummary(
  sim::MCResult,
  t=sim[1].t;
  quantiles=[0.05,0.95],
  #vars=observables(sim)
)
  m,v = timeseries_point_meanvar(sim,t)
  qlow = timeseries_point_quantile(sim,quantiles[1],t)
  qhigh = timeseries_point_quantile(sim,quantiles[2],t)
  med = timeseries_point_quantile(sim,0.5,t)

  trajectories = length(sim)

  EnsembleSummary{Float64, 2, typeof(t), typeof(m), typeof(v), typeof(med), typeof(qlow), typeof(qhigh)}(t,m,v,med,qlow,qhigh,trajectories,0.0,true)
end

function DiffEqBase.EnsembleAnalysis.EnsembleSummary(
  sim_pair::Pair{Symbol, MCResult},
  t=last(sim_pair)[1].t;
  quantiles=[0.05,0.95]
)
  first(sim_pair) => EnsembleSummary(last(sim_pair), t; quantiles)
end

function DiffEqBase.EnsembleAnalysis.EnsembleSummary(
  sim_vector::AbstractVector{Pair{Symbol, MCResult}};
  # t=?
  quantiles=[0.05,0.95]
)
  EnsembleSummary.(sim_vector; quantiles)
end

generate_cons(vp::AbstractVector{P},i)  where P<:Pair = NamedTuple([k=>generate_cons(v,i) for (k,v) in vp])
generate_cons(nt::NamedTuple,i) = NamedTuple{keys(nt)}([generate_cons(v,i) for v in nt])
generate_cons(v::Distribution,i) = rand(v)
generate_cons(v::Real,i) = v
generate_cons(v::AbstractVector{R},i) where R<:Float64 = v[i]

"""
    read_mcvecs(filepath::String)

Read table with pre-generated parameters for Monte-Carlo simulations. Typically used for virtual patients simulations

Arguments:

- `filepath`: path to the file with pre-generated parameters
"""
read_mcvecs(filepath::String) = DataFrame(CSV.File(filepath; typemap=Dict(Int => Float64)))
