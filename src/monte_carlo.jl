# RemoteChannel used for progress monitoring in parallel setup
const progch = RemoteChannel(()->Channel{Bool}(), 1)

# as in SciMLBase
DEFAULT_REDUCTION(u,data,I) = append!(u, data), false
DEFAULT_OUTPUT(sol,i) = sol

"""
    mc(scenario::Scenario,
      parameters_variation::Vector{<:Pair},
      num_iter::Int;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns [`MCResult`](@ref) type.

Example: `mc(scenario, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario` : simulation scenario of type [`Scenario`](@ref)
- `parameters_variation` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `progress_bar` : show progress bar. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `output_func` : the function determines what is saved from the solution to the output array. Defaults to saving the solution itself
- `reduction_func` : this function determines how to reduce the data in each batch. Defaults to appending the data from the batches
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function mc(
  scenario::Scenario,
  parameters_variation::Vector{P}, # input of `mc` level
  num_iter::Int;
  verbose=false,
  progress_bar=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  output_func=DEFAULT_OUTPUT,
  reduction_func = DEFAULT_REDUCTION,
  parallel_type=EnsembleSerial(),
  kwargs...
) where P<:Pair

  # check input names
  y_indexes = indexin(first.(parameters_variation), [keys(scenario.parameters)...])
  y_lost = isnothing.(y_indexes)
  @assert !any(y_lost) "The following keys are not found: $(first.(parameters_variation)[y_lost])."

  parameters_variation_nt = NamedTuple(parameters_variation)

  #(parallel_type == EnsembleSerial()) # tmp fix
  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled = progress_bar)
  
  function prob_func(prob,i,repeat)
    verbose && println("Processing iteration $i")
    progress_bar && (parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true))
    
    prob_i = remake_prob(scenario, generate_cons(parameters_variation_nt, i); safetycopy=true)
    return prob_i
    #=
    constants_total_i = merge_strict(scenario.parameters, generate_cons(parameters_variation_nt, i))
    u0, p0 = scenario.init_func(constants_total_i)

    return remake(scenario.prob; u0=u0, p=p0)
    =#
  end

  function _output(sol, i)
    # take numbers from p
    values_i = sol.prob.p[y_indexes]
    constants_i = NamedTuple(zip(first.(parameters_variation), values_i))
    # take simulated values from solution
    sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
    simulation = Simulation(sv, constants_i, sol.retcode)

    return (output_func(simulation, i), false)
  end

  prob = EnsembleProblem(scenario.prob;
    prob_func = prob_func,
    output_func = _output,
    reduction = reduction_func,
    safetycopy = false
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

  return MCResult(solution.u, has_saveat(scenario), scenario)
end

"""
    mc(scenario::Scenario,
      parameters_variation::DataFrame,
      num_iter::Int;
      kwargs...
    )

Run Monte-Carlo simulations with single scenario `Scenario`. Returns [`MCResult`](@ref) type.

Example: `mc(scn1, DataFrame(k2=rand(3),k3=rand(3)), 1000)`

Arguments:

- `scenario` : simulation scenario of type [`Scenario`](@ref)
- `parameters_variation` : DataFrame with pre-generated parameters.
- `num_iter` : number of Monte-Carlo iterations 
- kwargs : other solver related arguments supported by `mc(scenario::Scenario, parameters_variation::Vector, num_iter::Int64)`
"""
function mc(
  scenario::Union{Scenario, Vector{Pair{Symbol,Scenario}}, Vector{Scenario}, Platform},
  parameters_variation::DataFrame;
  num_iter::Int = size(parameters_variation)[1],
  kwargs...
)
  parameters_pairs = Pair[]
  
  for pstr in names(parameters_variation)
    psym = Symbol(pstr)
  #  if !(psym in cons)
  #   @warn "$psym is not found in models constants."
  #  end
    # @assert (psym in cons) "$psym is not found in models constants."   
    push!(parameters_pairs, psym=>parameters_variation[!,psym])
  end

  return mc(scenario, parameters_pairs, num_iter; kwargs...)
end

# multi scenario Monte-Carlo

"""
    mc(scenario_pairs::Vector{<:Pair},
      parameters_variation::Vector{<:Pair},
      num_iter::Int64;
      verbose=false,
      alg=DEFAULT_ALG,
      reltol=DEFAULT_SIMULATION_RELTOL,
      abstol=DEFAULT_SIMULATION_ABSTOL,
      parallel_type=EnsembleSerial(),
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns `Vector{MCResult}` type.

Example: `mc([:c1=>scn1,:c2=>scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of pairs containing names and scenarios of type [`Scenario`](@ref)
- `parameters_variation` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- `verbose` : print iteration progress. Default is `false`
- `progress_bar` : show progress bar. Default is `false`
- `alg` : ODE solver. See SciML docs for details. Default is AutoTsit5(Rosenbrock23())
- `reltol` : relative tolerance. Default is 1e-3
- `abstol` : relative tolerance. Default is 1e-6
- `output_func` : the function determines what is saved from the solution to the output array. Defaults to saving the solution itself
- `reduction_func` : this function determines how to reduce the data in each batch. Defaults to appending the data from the batches
- `parallel_type` : parallel setup. See SciML docs for details. Default is no parallelism: EnsembleSerial()
- kwargs : other solver related arguments supported by DiffEqBase.solve. See SciML docs for details
"""
function mc(
  scenario_pairs::Vector{CP},
  parameters_variation::Vector{PP},
  num_iter::Int;
  verbose=false,
  progress_bar=false,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_SIMULATION_RELTOL,
  abstol=DEFAULT_SIMULATION_ABSTOL,
  output_func=DEFAULT_OUTPUT,
  reduction_func = DEFAULT_REDUCTION,
  parallel_type=EnsembleSerial(),
  kwargs...
) where {CP<:Pair, PP<:Pair}

  # check input names
  for scenario_pair in scenario_pairs
    y_indexes = indexin(first.(parameters_variation), [keys(last(scenario_pair).parameters)...])
    y_lost = isnothing.(y_indexes)
    @assert !any(y_lost) "The following keys are not found: $(first.(parameters_variation)[y_lost])."
  end

  parameters_variation_nt = NamedTuple(parameters_variation)
  parameters_pregenerated = [generate_cons(parameters_variation_nt, i) for i in 1:num_iter]
  lp = length(parameters_pregenerated)
  lc = length(scenario_pairs)
  iter = collect(Iterators.product(1:lp,1:lc))

  p = Progress(num_iter, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=50, enabled=progress_bar)
  
  function prob_func(prob,i,repeat)
    iter_i = iter[i]
    verbose && println("Processing scenario $(iter_i[2]) iteration $(iter_i[1])")
    progress_bar && (parallel_type != EnsembleDistributed() ? next!(p) : put!(progch, true))

    scn_i = last(scenario_pairs[iter_i[2]])
    parameters_i = parameters_pregenerated[iter_i[1]]

    prob_i = remake_prob(scn_i, parameters_i; safetycopy=true)
    return prob_i
    #=
    constants_total_i = merge_strict(scn_i.parameters, parameters_i)
    u0, p0 = scn_i.init_func(constants_total_i)

    return remake(scn_i.prob; u0=u0, p=p0)
    =#
  end

  function _output(sol, i)
    iter_i = iter[i]
    # takes parameters_variation from pre-generated
    constants_i = parameters_pregenerated[iter_i[1]]
    # take simulated values from solution
    sv = sol.prob.kwargs[:callback].discrete_callbacks[1].affect!.saved_values
    simulation = Simulation(sv, constants_i, sol.retcode)

    return (output_func(simulation, i), false)
  end

  prob = EnsembleProblem(last(scenario_pairs[1]).prob;
    prob_func = prob_func,
    output_func = _output,
    reduction = reduction_func,
    safetycopy = false
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
    MCResult(solution.u[lp*(i-1)+1:i*lp], has_saveat(last(scenario_pairs[i])), last(scenario_pairs[i]))
  end
  return ret
end

"""
    mc(scenario_pairs::Vector{<:AbstractScenario},
      parameters_variation::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single scenario. Returns `Vector{MCResult}` type.

Example: `mc([scn1,scn2], [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `scenario_pairs` : vector of scenarios of type [`Scenario`](@ref)
- `parameters_variation` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(scenario_pairs::Vector{<:Pair}, parameters_variation::Vector, num_iter::Int64)`
"""
function mc(
  scenario_pairs::Vector{C},
  parameters_variation::Vector{P},
  num_iter::Int;
  kwargs...
) where {C<:AbstractScenario, P<:Pair}

  scenario_pairs = [(Symbol("_$i") => scn) for (i, scn) in pairs(scenario_pairs)]
  return mc(scenario_pairs, parameters_variation, num_iter; kwargs...)
end

"""
    mc(platform::Platform, 
      parameters_variation::Vector{<:Pair},
      num_iter::Int64;
      kwargs...
    )

Run Monte-Carlo simulations with single `Scenario`. Returns `Vector{MCResult}` type.

Example: `mc(platform, [:k2=>Normal(1e-3,1e-4), :k3=>Uniform(1e-4,1e-2)], 1000)`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `parameters_variation` : parameters variation setup
- `num_iter` : number of Monte-Carlo iterations
- kwargs : other solver related arguments supported by `mc(scenario_pairs::Vector{<:Pair}, parameters_variation::Vector, num_iter::Int64)`
"""
function mc(
  platform::Platform,
  parameters_variation::Vector{P},
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

  return mc(scenario_pairs, parameters_variation, num_iter; kwargs...)
end

"""
    mc!(mcres::M; 
      success_status::Vector{Symbol}=[:Success,:Terminated]
      kwargs...
    ) where M <: Union{MCResult, Vector{MCResult}, Vector{Pair}}

Re-run failed Monte-Carlo simulations with single `Scenario`. Updates `MCResult` type.

Example: `mc!(mcres)`

Arguments:

- `mcres` : Monte-Carlo result of type `MCResult`
- `success_status` : Vector of success statuses. Default is `[:Success,:Terminated]`
- kwargs : other solver related arguments supported by `mc(scenario::Scenario, parameters_variation::Vector, num_iter::Int64)`
"""
function mc!(mcres::MCResult; success_status::Vector{Symbol}=[:Success,:Terminated], kwargs...)
  scen = scenario(mcres)
  err_idxs = [i for i in 1:length(mcres) if status(mcres[i]) ∉ success_status]
  mcvecs = DataFrame([NamedTuple(parameters(mcres[i])) for i in err_idxs]) # XXX: maybe NamesTuple is not required
  mcres_upd = mc(scen, mcvecs; kwargs...)
  for i in eachindex(err_idxs)
    mcres.sim[err_idxs[i]] = mcres_upd[i]
  end
  return nothing
end

function mc!(mcres::Vector{M}; kwargs...) where M<:MCResult
  for mcr in mcres
    mc!(mcr; kwargs...)
  end
end

mc!(mcres::Vector{P}; kwargs...) where P<:Pair = mc!(last.(mcres); kwargs...)



########################################## Statistics ######################################################

# currently median and quantile don't output LVector

function DiffEqBase.EnsembleAnalysis.get_timestep(mcr::MCResult,i) 
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
  quantiles=[0.05,0.95]
)
  m,v = timeseries_point_meanvar(sim,t)
  qlow = timeseries_point_quantile(sim,quantiles[1],t)
  qhigh = timeseries_point_quantile(sim,quantiles[2],t)
  med = timeseries_point_quantile(sim,0.5,t)

  trajectories = length(sim)

  ens = EnsembleSummary{Float64, 2, typeof(t), typeof(m), typeof(v), typeof(med), typeof(qlow), typeof(qhigh)}(t,m,v,med,qlow,qhigh,trajectories,0.0,true)
  LabelledEnsembleSummary(ens,observables(sim))
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
generate_cons(v::AbstractVector{R},i) where R<:Real = v[i]

"""
    read_mcvecs(filepath::String)

Read table with pre-generated parameters for Monte-Carlo simulations. Typically used for virtual patients simulations

Arguments:

- `filepath`: path to the file with pre-generated parameters
"""
read_mcvecs(filepath::String) = DataFrame(CSV.File(filepath; typemap=Dict(Int => Float64)))
