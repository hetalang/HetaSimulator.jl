const NORMAL = :normal
const LOGNORMAL = :lognormal
const SIGMA = :sigma
const MEAN = :mean

# CSV methods

function add_measurements!(
  condition::Condition,
  vector::AbstractVector;
  subset::AbstractVector{P} = Pair{Symbol, Symbol}[]
) where P <: Pair{Symbol, Symbol}
  selected_rows = _subset(vector, subset)

  for row in selected_rows
    _add_measurement!(condition, row)
  end
end

function add_measurements!(
  platform::Platform,
  vector::AbstractVector;
  subset::AbstractVector{P} =  Pair{Symbol, Symbol}[]
) where P <: Pair{Symbol, Symbol}
  selected_rows = _subset(vector, subset)

  # we will store here lost condition names
  lost_refs = Symbol[]

  for row in selected_rows
    condition_ref = row[:condition]

    if !haskey(platform.conditions, condition_ref)
      push!(lost_refs, condition_ref)
    else
      condition = platform.conditions[condition_ref]
      _add_measurement!(condition, row)
    end
  end

  if length(lost_refs) > 0
    @warn "Lost condition names: $(unique(lost_refs)). Some measurement points haven't been added."
  end

  return nothing
end

# DataFrame methods
"""
    add_measurements!(
      condition::Condition,
      df::DataFrame;
      kwargs...
    )

Adds measurements to `Condition`

Arguments:

- `condition` : simulation condition of type [`Condition`](@ref)
- `df` : `DataFrame` with measurements, typically obtained with [`read_measurements`](@ref) function
- `subset` : subset of measurements which will be added to the `Condition`. Default `Pair{Symbol, Symbol}[]` adds all measurements from the `df`
"""
function add_measurements!(
  condition::Condition,
  df::DataFrame;
  kwargs...
)
  add_measurements!(condition, eachrow(df); kwargs...)
end

"""
    add_measurements!(
      platform::Platform,
      df::DataFrame;
      kwargs...
    )

Adds measurements to `Condition`

Arguments:

- `platform` : platform of [`Platform`](@ref) type
- `df` : `DataFrame` with measurements, typically obtained with [`read_measurements`](@ref) function
- `subset` : subset of measurements which will be added to the `Condition`. Default `Pair{Symbol, Symbol}[]` adds all measurements from the `df`
"""
function add_measurements!(
  platform::Platform,
  df::DataFrame;
  kwargs...
)
  add_measurements!(platform, eachrow(df); kwargs...)
end

# private function to add one measurement row into condition 

function _add_measurement!(condition::Condition, row::Any) # maybe not any
  _t = row[:t]
  _val = row[:measurement]
  _scope = haskey(row, :scope) ? row[:scope] : missing

  _type = haskey(row, Symbol("prob.type")) ? row[Symbol("prob.type")] : missing
  type = ismissing(_type) ? NORMAL : _type

  if type in [NORMAL, LOGNORMAL]
    _mean = typed(row[Symbol("prob.$MEAN")])
    _sigma = typed(row[Symbol("prob.$SIGMA")])

    point = (type == LOGNORMAL) ? LogNormalMeasurementPoint(_t, _val, _scope, _mean, _sigma) : NormalMeasurementPoint(_t, _val, _scope, _mean, _sigma)
  else 
    error("Distribution value $type is wrong or not supported. Supported distributions are: $Normal, $Lognormal")
  end

  push!(condition.measurements, point)
end

# helper to read from csv and xlsx

function read_measurements_csv(filepath::String; kwargs...)
  df = DataFrame(CSV.File(
    filepath;
    typemap = Dict(Int64=>Float64, Int32=>Float64),
    types = Dict(:t=>Float64, :measurement=>Float64, :scope=>Symbol, :condition=>Symbol, Symbol("prob.type")=>Symbol),
    kwargs...)
  )
  assert_measurements(df)
  
  return df
end

function read_measurements_xlsx(filepath::String, sheet=1; kwargs...)
  df = DataFrame(XLSX.readtable(filepath, sheet,infer_eltypes=true)...)
  assert_measurements(df)

  df[!,:t] .= Float64.(df[!,:t])
  df[!,:measurement] .= Float64.(df[!,:measurement])
  haspropery(df, :scope) && (df[!,:scope] .= Symbol.(df[!,:scope]))
  df[!,:condition] .= Symbol.(df[!,:condition])
  haspropery(df, Symbol("prob.type")) && (df[!,Symbol("prob.type")] .= Symbol.(df[!,Symbol("prob.type")]))

  return df
end

"""
    read_measurements(filepath::String, sheet=1; kwargs...)

Reads table file with measurements to `DataFrame`

Arguments:

- `filepath` : path to table file. Supports ".csv" and ".xlsx" files
- `sheet` : number of sheet in case of ".xlsx" file. Default is `1`
- kwargs : other arguments supported by `CSV.File`
"""
function read_measurements(filepath::String, sheet=1; kwargs...)
  ext = splitext(filepath)[end]

  if ext == ".csv"
    df = read_measurements_csv(filepath; kwargs...)
  elseif ext == ".xlsx"
    df = read_measurements_xlsx(filepath, sheet)
  else  
    error("Extension $ext is not supported.")
  end
  return df
end

function assert_measurements(df)
  names_df = names(df)
  for f in ["t", "measurement", "condition"]
    @assert f ∈ names_df "Required column name $f is not found in measurements table."
  end
  return nothing
end
