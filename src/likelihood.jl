
function likelihood(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  params::Vector{Pair{Symbol,Float64}};
  parameters_upd::Union{Nothing, Vector{P}}=nothing,
  alg=DEFAULT_ALG,
  reltol=DEFAULT_FITTING_RELTOL,
  abstol=DEFAULT_FITTING_ABSTOL,
  parallel_type=EnsembleSerial(),
  kwargs... # other arguments to sim()
) where {C<:AbstractScenario, P<:Pair}

  # names of parameters used in fitting and saved in params field of solution
  params_names = first.(params)

  selected_scenario_pairs = Pair{Symbol,Scenario}[]
  for scenario_pair in scenario_pairs # iterate through scenarios names
    if isempty(last(scenario_pair).measurements)
      @warn "Scenario \":$(first(scenario_pair))\" has no measurements. It will be excluded from fitting."
    else
      push!(selected_scenario_pairs, scenario_pair)
    end
  end
  
  isempty(selected_scenario_pairs) && throw("No measurements points included in scenarios.")
  
  # update saveat and initial values
  selected_prob = []
  for scn in selected_scenario_pairs
    prob_i = remake_saveat(last(scn).prob, last(scn).measurements)
    prob_i = !isnothing(parameters_upd) ? update_init_values(prob_i, last(scn).init_func, NamedTuple(parameters_upd)) : prob_i
    push!(selected_prob, prob_i)
  end

  function prob_func(x)
    function internal_prob_func(prob,i,repeat)
      update_init_values(selected_prob[i],last(selected_scenario_pairs[i]).init_func,x)
    end
  end

  function _output(sol, i)
    sol.retcode != :Success && error("Simulated scenario $i returned $(sol.retcode) status")
    sim = build_results(sol,last(selected_scenario_pairs[i]), params_names)
    loss_val = loss(sim, sim.scenario.measurements) 
    (loss_val, false)
  end

  function _reduction(u, batch, I)
    (sum(batch),false)
  end

  prob(x) = EnsembleProblem(EMPTY_PROBLEM;
    prob_func = prob_func(x),
    output_func = _output,
    reduction = _reduction
  )

  ###
    x_nt = NamedTuple{Tuple(params_names)}(last.(params))
    prob_i = prob(x_nt)
    sol = solve(prob_i, alg, parallel_type;
        trajectories = length(selected_scenario_pairs),
        reltol,
        abstol,
        save_start = false, 
        save_end = false, 
        save_everystep = false, 
        kwargs...
    )
    
    #println(x_pairs)
    return sol.u
end

function likelihood(
  scenario_pairs::AbstractVector{Pair{Symbol, C}},
  params_df::DataFrame;
  kwargs...
) where C<:AbstractScenario
  
  gdf = groupby(params_df, :estimate)
  @assert haskey(gdf, (true,)) "No parameters to estimate."

  params = gdf[(true,)].parameter .=> gdf[(true,)].nominal
  parameters_upd = haskey(gdf, (false,)) ? gdf[(false,)].parameter .=> gdf[(false,)].nominal : nothing

  likelihood(scenario_pairs, params; parameters_upd, kwargs...)
end

function likelihood(
  platform::Platform,
  params;
  scenarios::Union{AbstractVector{Symbol}, Nothing} = nothing, # all if nothing
  kwargs... 
)
  if isnothing(scenarios)
    scenario_pairs = [platform.scenarios...]
  else
    scenario_pairs = Pair{Symbol,AbstractScenario}[]
    for scn_name in scenarios
      @assert haskey(platform.scenarios, scn_name) "No scenario :$scn_name found in the platform."
      push!(scenario_pairs, scn_name=>platform.scenarios[scn_name])
    end
  end

  return likelihood(scenario_pairs, params; kwargs...)
end
