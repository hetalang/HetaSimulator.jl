const CONSTANT_PREFIX = "constants"
const SWITCHER_PREFIX = "switchers"
const SAVEAT_HEADER = Symbol("saveat[]")
const TSPAN_HEADER = Symbol("tspan")
const OBSERVABLES_HEADER = Symbol("observables[]")

# general interface
function Cond(
  model::QModel;
  constants::Vector{Pair{Symbol,Float64}} = Pair{Symbol,Float64}[],
  events_on::Union{Nothing, Vector{Pair{Symbol,Bool}}} = Pair{Symbol,Bool}[], 
  measurements::Vector{AbstractMeasurementPoint} = AbstractMeasurementPoint[],
  saveat::Union{Nothing,AbstractVector{T}} = nothing,
  tspan::Union{Nothing,Tuple{S,S}} = nothing,
  observables::Union{Nothing,Vector{Symbol}} = nothing
) where {T<:Real,S<:Real}
  _observables = observables === nothing ? model.observables : observables # use default if not set
  _saving = model.saving_generator(_observables)

  return Cond(model, constants, events_on, measurements, saveat, tspan, _observables, _saving)
end

# CSV methods
function add_conditions!(
  platform::QPlatform,
  vector::AbstractVector;
  subset::Union{Dict{Symbol}, Nothing} = nothing
)
  selected_rows = _subset(vector, subset)

  for row in selected_rows
    _add_condition!(platform, row)
  end

  return nothing
end

# DataFrame methods
function add_conditions!(
  platform::QPlatform,
  df::DataFrame;
  kwargs...
)
  add_conditions!(platform, eachrow(df); kwargs...)
end

# private function to add one condition row into platform

function _add_condition!(platform::QPlatform, row::Any) # maybe not any
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

# helper to read from csv

function read_conditions_csv(filepath::String; kwargs...)
  csv = CSV.File(
    filepath,
    types = Dict(:id => Symbol, :tspan => Float64);
    kwargs...
  )
  return csv
end
