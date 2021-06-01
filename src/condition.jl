const CONSTANT_PREFIX = "constants"
const SWITCHER_PREFIX = "switchers"
const SAVEAT_HEADER = Symbol("saveat[]")
const TSPAN_HEADER = Symbol("tspan")
const OBSERVABLES_HEADER = Symbol("observables[]")

# general interface
function Cond(
  model::Model;
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  kwargs...
)
  # ode problem
  prob = build_ode_problem(model; kwargs...)

  return Cond(model.init_func, prob, measurements)
end

# CSV methods
function add_conditions!(
  platform::Platform,
  vector::AbstractVector;
  subset::AbstractVector{P} = Pair{Symbol, Symbol}[]
) where P <: Pair{Symbol, Symbol}
  selected_rows = _subset(vector, subset)

  for row in selected_rows
    _add_condition!(platform, row)
  end

  return nothing
end

# DataFrame methods
function add_conditions!(
  platform::Platform,
  df::DataFrame;
  kwargs...
)
  add_conditions!(platform, eachrow(df); kwargs...)
end

# private function to add one condition row into platform

function _add_condition!(platform::Platform, row::Any) # maybe not any
  _id = row[:id]
  model_name = get(row, :model, :nameless)

  if !haskey(platform.models, model_name)
    @warn "Lost model $(model_name). Cond $_id has been skipped."
    return nothing # BRAKE
  else
    model = platform.models[model_name]
  end

  # iterate through constants
  _constants = Pair{Symbol,Float64}[]
  _events_on = Pair{Symbol,Bool}[]
  for key in keys(row)
    if !ismissing(row[key])
      splitted_key = split(string(key), ".")
      if splitted_key[1] == CONSTANT_PREFIX
        push!(_constants, Symbol(splitted_key[2]) => row[key])
      elseif splitted_key[1] == SWITCHER_PREFIX
        push!(_events_on, Symbol(splitted_key[2]) => row[key])
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

  condition = Cond(
    model;
    constants = _constants,
    events_on = _events_on,
    saveat = _saveat,
    tspan = _tspan,
    observables = _observables
  )

  push!(platform.conditions, _id => condition)
end

# helper to read from csv and xlsx

function read_conditions_csv(filepath::String; kwargs...)
  df = DataFrame(CSV.File(
    filepath,
    types = Dict(:id => Symbol, :model=>Symbol, :tspan => Float64);
    kwargs...)
  )
  assert_conditions(df)
  
  return df
end

function read_conditions_xlsx(filepath::String, sheet=1; kwargs...)
  df = DataFrame(XLSX.readtable(filepath, sheet,infer_eltypes=true)...)
  assert_conditions(df)

  df[!,:id] .= Symbol.(df[!,:id])
  "tspan" in names(df) && (df[!,:tspan] .= float64.(df[!,:tspan]))
  "model" in names(df) && (df[!,:model] .= Symbol.(df[!,:model]))
  return df
end

function read_conditions(filepath::String, sheet=1; kwargs...)
  ext = splitext(filepath)[end]

  if ext == ".csv"
    df = read_conditions_csv(filepath; kwargs...)
  elseif ext == ".xlsx"
    df = read_conditions_xlsx(filepath, sheet)
  else  
    error("Extension $ext is not supported.")
  end
  return df
end

function assert_conditions(df)
  names_df = names(df)
  for f in ["id"]
    @assert f ∈ names_df "Required column name $f is not found in measurements table."
  end
  return nothing
end