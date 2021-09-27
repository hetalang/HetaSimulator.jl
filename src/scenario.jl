const CONSTANT_PREFIX = "parameters"
const SWITCHER_PREFIX = "events_active"
const SWITCHER_SAVE_PREFIX = "events_save"
const SAVEAT_HEADER = Symbol("saveat[]")
const TSPAN_HEADER = Symbol("tspan")
const OBSERVABLES_HEADER = Symbol("observables[]")

# general interface
"""
    Scenario(model::Model;
      measurements::Vector{AbstractMeasurementPoint}=AbstractMeasurementPoint[],
      observables::Union{Nothing,Vector{Symbol}}=nothing,
      parameters::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
      events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
      events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}} = (true,true), 
      saveat::Union{Nothing,AbstractVector} = nothing,
      tspan::Union{Nothing,Tuple} = nothing,
      save_scope::Bool = true,
    )

Builds simulation scenario of type [`Scenario`](@ref)
Example: `Scenario(model; tspan = (0., 200.), saveat = [0.0, 150., 250.])`

Arguments:

- `model` : model of type [`Model`](@ref)
- `measurements` : `Vector` of measurements. Default is empty `Vector{AbstractMeasurementPoint}`
- `observables` : names of output observables. Overwrites default model's values. Default is `nothing`
- `parameters` : parameters variation setup. Default is empty `Vector{Pair}`
- `events_active` : `Vector` of `Pair`s containing events' names and true/false values. Overwrites default model's values. Default is empty `Vector{Pair}`
- `events_save` : `Tuple` or `Vector{Tuple}` marking whether to save solution before and after event. Default is `(true,true)` for all events
- `saveat` : time points, where solution should be saved. Default `nothing` values stands for saving solution at timepoints reached by the solver 
- `tspan` : time span for the ODE problem
- `save_scope` : should scope be saved together with solution. Default is `true`
"""
function Scenario(
  model::Model;
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  kwargs... # all arguments of build_ode_problem()
)
  # ODE problem
  prob = build_ode_problem(
    model;
    observables_ = observables,
    kwargs...
  )

  return Scenario(model.init_func, prob, measurements)
end

# CSV methods
function add_scenarios!(
  platform::Platform,
  vector::AbstractVector;
  subset::AbstractVector{P} = Pair{Symbol, Symbol}[]
) where P <: Pair{Symbol, Symbol}
  selected_rows = _subset(vector, subset)

  for row in selected_rows
    _add_scenario!(platform, row)
  end

  return nothing
end

# DataFrame methods
"""
    add_scenarios!(
      platform::Platform,
      df::DataFrame;
      subset::AbstractVector{P} = Pair{Symbol, Symbol}[]
    ) where P <: Pair{Symbol, Symbol}

Adds a new `Scenario` to the `Platform`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `df` : `DataFrame` with scenarios setup, typically obtained with [`read_scenarios`](@ref) function
- `subset` : subset of scenarios which will be added to the `platform`. Default `Pair{Symbol, Symbol}[]` adds all scenarios from the `df`
"""
function add_scenarios!(
  platform::Platform,
  df::DataFrame;
  kwargs...
)
  add_scenarios!(platform, eachrow(df); kwargs...)
end

# private function to add one scenario row into platform

function _add_scenario!(platform::Platform, row::Any) # maybe not any
  _id = row[:id]
  model_name = get(row, :model, :nameless)

  if !haskey(platform.models, model_name)
    @warn "Lost model $(model_name). Scenario $_id has been skipped."
    return nothing # BRAKE
  else
    model = platform.models[model_name]
  end

  # iterate through parameters
  _parameters = Pair{Symbol,Float64}[]
  _events_active = Pair{Symbol,Bool}[]
  _events_save = Pair{Symbol, Tuple{Bool, Bool}}[]
  for key in keys(row)
    if !ismissing(row[key])
      splitted_key = split(string(key), ".")
      if splitted_key[1] == CONSTANT_PREFIX
        push!(_parameters, Symbol(splitted_key[2]) => row[key])
      elseif splitted_key[1] == SWITCHER_PREFIX
        push!(_events_active, Symbol(splitted_key[2]) => bool(row[key]))
      elseif splitted_key[1] == SWITCHER_SAVE_PREFIX
        save_evt_vec = split(row[key], ";")
        @assert length(save_evt_vec) == 2 "Events saving setup accepts two values (e.g. true;false). Check the scenarios table."
        push!(_events_save, Symbol(splitted_key[2]) => (bool(save_evt_vec[1]), bool(save_evt_vec[2])))
      end
    end
  end

  if haskey(row, SAVEAT_HEADER) && !ismissing(row[SAVEAT_HEADER])
    saveat_str = split(row[SAVEAT_HEADER], ";")
    _saveat = parse.(Float64, saveat_str)
  else  
    _saveat = nothing
  end
  
  if haskey(row, TSPAN_HEADER) && !ismissing(row[TSPAN_HEADER])
    _tspan = (0., row[TSPAN_HEADER])
  else  
    _tspan = nothing
  end
  
  if haskey(row, OBSERVABLES_HEADER) && !ismissing(row[OBSERVABLES_HEADER])
    observables_str = split(row[OBSERVABLES_HEADER], ";")
    _observables = Symbol.(observables_str)
  else  
    _observables = nothing
  end

  scenario = Scenario(
    model;
    parameters = _parameters,
    events_active = _events_active,
    events_save = _events_save,
    saveat = _saveat,
    tspan = _tspan,
    observables = _observables
  )

  push!(platform.scenarios, _id => scenario)
end

# helper to read from csv and xlsx

function read_scenarios_csv(filepath::String; kwargs...)
  df = DataFrame(CSV.File(
    filepath,
    types = Dict(:id => Symbol, :model=>Symbol, :tspan => Float64);
    kwargs...)
  )
  assert_scenarios(df)
  
  return df
end

function read_scenarios_xlsx(filepath::String, sheet=1; kwargs...)
  df = DataFrame(XLSX.readtable(filepath, sheet,infer_eltypes=true)...)
  assert_scenarios(df)

  df[!,:id] .= Symbol.(df[!,:id])
  "tspan" in names(df) && (df[!,:tspan] .= float64.(df[!,:tspan]))
  "model" in names(df) && (df[!,:model] .= Symbol.(df[!,:model]))
  return df
end

"""
    read_scenarios(filepath::String, sheet=1; kwargs...)

Reads table file with scenarios to `DataFrame`

Arguments:

- `filepath` : path to table file. Supports ".csv" and ".xlsx" files
- `sheet` : number of sheet in case of ".xlsx" file. Default is `1`
- kwargs : other arguments supported by `CSV.File`
"""
function read_scenarios(filepath::String, sheet=1; kwargs...)
  ext = splitext(filepath)[end]

  if ext == ".csv"
    df = read_scenarios_csv(filepath; kwargs...)
  elseif ext == ".xlsx"
    df = read_scenarios_xlsx(filepath, sheet)
  else  
    error("Extension $ext is not supported.")
  end
  return df
end

function assert_scenarios(df)
  names_df = names(df)
  for f in ["id"]
    @assert f ∈ names_df "Required column name $f is not found in measurements table."
  end
  return nothing
end