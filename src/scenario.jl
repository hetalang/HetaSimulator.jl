const PARAMETERS_PREFIX = "parameters"
const EVENT_PREFIX = "events_active"
const EVENT_SAVE_PREFIX = "events_save"
const SAVEAT_HEADER = Symbol("saveat[]")

const TSPAN_HEADER = Symbol("tspan")
const OBSERVABLES_HEADER = Symbol("observables[]")
const TAGS_HEADER = Symbol("tags[]")
const GROUP_HEADER = Symbol("group")

# general interface
"""
    Scenario(
      model::Model,
      tspan;
      measurements::Vector{AbstractMeasurementPoint}=AbstractMeasurementPoint[],
      observables::Union{Nothing,Vector{Symbol}}=nothing,
      parameters::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
      events_active::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[],
      events_save::Union{Tuple,Vector{Pair{Symbol, Tuple{Bool, Bool}}}} = (true,true),
      saveat::Union{Nothing,AbstractVector} = nothing,

      save_scope::Bool = true,
    )

Builds simulation scenario of type [`Scenario`](@ref)

Example: `Scenario(model, (0., 200.))`

Arguments:

- `model` : model of type [`Model`](@ref)
- `tspan` : time span for the ODE problem
- `measurements` : `Vector` of measurements. Default is empty `Vector{AbstractMeasurementPoint}`
- `observables` : names of output observables. Overwrites default model's values. Default is `nothing`
- `tags` :
- `group` :
- `parameters` : `Vector` of `Pair`s containing parameters' names and values. Overwrites default model's values. Default is empty vector.
- `events_active` : `Vector` of `Pair`s containing events' names and true/false values. Overwrites default model's values. Default is empty `Vector{Pair}`
- `events_save` : `Tuple` or `Vector{Tuple}` marking whether to save solution before and after event. Default is `(true,true)` for all events
- `saveat` : time points, where solution should be saved. Default `nothing` values stands for saving solution at timepoints reached by the solver 

- `save_scope` : should scope be saved together with solution. Default is `true`
"""
function Scenario(
  model::Model,
  tspan;
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  observables::Union{Nothing,Vector{Symbol}} = nothing,
  tags::AbstractVector{Symbol} = Symbol[],
  group::Union{Symbol, Nothing} = nothing,
  parameters::Vector{Pair{Symbol,N}} = Pair{Symbol,Float64}[],
  kwargs... # all arguments of build_ode_problem()
) where N <: Number

  params_total = merge_strict(model.constants, NamedTuple(parameters))
  
  # ODE problem
  prob = build_ode_problem(
    model,
    tspan;
    observables_ = observables,
    params = params_total,
    kwargs...
  )

  return Scenario(model.init_func, prob, measurements, tags, group, params_total)
end

# Scenario struct method
function add_scenarios!(p, scen::Vector{P}) where P <: Pair
  [push!(scenarios(p), s) for s in scen]
  return nothing
end

# CSV methods
function add_scenarios!(
  platform::Platform,
  vector::DataFrames.DataFrameRows;
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
      if splitted_key[1] == PARAMETERS_PREFIX
        push!(_parameters, Symbol(splitted_key[2]) => row[key])
      elseif splitted_key[1] == EVENT_PREFIX
        push!(_events_active, Symbol(splitted_key[2]) => bool(row[key]))
      elseif splitted_key[1] == EVENT_SAVE_PREFIX
        save_evt_vec = split(row[key], ";")
        @assert length(save_evt_vec) == 2 "Events saving setup accepts two values (e.g. true;false). Check the scenarios table."
        push!(_events_save, Symbol(splitted_key[2]) => (bool(save_evt_vec[1]), bool(save_evt_vec[2])))
      end
    end
  end
  
  if haskey(row, SAVEAT_HEADER) && !ismissing(row[SAVEAT_HEADER])
    save_times = row[SAVEAT_HEADER]
    if typeof(save_times) <: Number
      _saveat = [Float64(save_times)] 
    elseif typeof(save_times) <: AbstractString
      _saveat = Float64[]
      _saveat_vec = split(save_times, ";")
      [append!(_saveat, parse_saveat(sv)) for sv in _saveat_vec]
    else
      @warn "saveat for Scenario $_id is not properly formatted"
    end
  else  
    _saveat = nothing
  end
  
  if haskey(row, TSPAN_HEADER) && !ismissing(row[TSPAN_HEADER])
    _tspan = (0., Float64(row[TSPAN_HEADER]))
  else  
    error("'tspan' value not found in Scenario $_id")
  end
  
  if haskey(row, OBSERVABLES_HEADER) && !ismissing(row[OBSERVABLES_HEADER])
    observables_str = split(row[OBSERVABLES_HEADER], ";")
    _observables = Symbol.(observables_str)
  else  
    _observables = nothing
  end

  # create tags
  if haskey(row, TAGS_HEADER) && !ismissing(row[TAGS_HEADER])
    tags_str = split(row[TAGS_HEADER], ";")
    _tags = Symbol.(tags_str)
  else
    _tags = Symbol[]
  end

  # create group
  if haskey(row, GROUP_HEADER) && !ismissing(row[GROUP_HEADER])
    _group = Symbol(row[GROUP_HEADER])
  else
    _group = nothing
  end

  scenario = Scenario(
    model,
    _tspan;
    parameters = _parameters,
    events_active = _events_active,
    events_save = _events_save,
    saveat = _saveat,
    observables = _observables,
    tags = _tags,
    group = _group
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
  df = DataFrame(XLSX.readtable(filepath, sheet; infer_eltypes=true, kwargs...))
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
- kwargs : other arguments supported by `CSV.File` or `XLSX.readtable`
"""
function read_scenarios(filepath::String, sheet=1; kwargs...)
  ext = splitext(filepath)[end]

  if ext == ".csv"
    df = read_scenarios_csv(filepath; kwargs...)
  elseif ext == ".xlsx"
    df = read_scenarios_xlsx(filepath, sheet; kwargs...)
  else  
    error("Extension $ext is not supported.")
  end
  return sanitizenames!(df)
end

function assert_scenarios(df)
  names_df = names(df)
  for f in ["id"]
    @assert f ∈ names_df "Required column name $f is not found in measurements table."
  end
  return nothing
end

function parse_saveat(s::AbstractString)
  ps = parse.(Float64, split(s,":"))
  if length(ps) == 1
    return ps
  elseif length(ps) == 2
    return collect(ps[1]:ps[2])
  elseif length(ps) == 3
    return collect(ps[1]:ps[2]:ps[3])
  else
    throw("Saveat should be either a Number or a StepRange")
  end
end