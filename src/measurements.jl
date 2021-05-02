const NORMAL = :normal
const SIGMA = :sigma
const MEAN = :mean

# CSV methods

function add_measurements!(
  condition::Cond,
  vector::AbstractVector;
  subset::Union{Dict{Symbol}, Nothing} = nothing
)
  selected_rows = _subset(vector, subset)

  for row in selected_rows
    _add_measurement!(condition, row)
  end
end

function add_measurements!(
  platform::QPlatform,
  vector::AbstractVector;
  subset::Union{Dict{Symbol}, Nothing} = nothing
)
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

function add_measurements!(
  condition::Cond,
  df::DataFrame;
  kwargs...
)
  add_measurements!(condition, eachrow(df); kwargs...)
end

function add_measurements!(
  platform::QPlatform,
  df::DataFrame;
  kwargs...
)
  add_measurements!(platform, eachrow(df); kwargs...)
end

# private function to add one measurement row into condition 

function _add_measurement!(condition::Cond, row::Any) # maybe not any
  _t = row[:t]
  _val = row[:measurement]
  _scope = row[:scope]

  if row[:distribution] == NORMAL    
    _mean = typed(row[Symbol("parameters.$MEAN")])
    _sigma = typed(row[Symbol("parameters.$SIGMA")])

    point = NormalMeasurementPoint(_t, _val, _scope, _mean, _sigma)
  else 
    error("Distribution value $(row[:distribution]) is wrong or not supported. Supported distributions are: $Normal")
  end

  push!(condition.measurements, point)
end

# helper to read from csv and xlsx

function read_measurements_csv(filepath::String; kwargs...)
  df = DataFrame(CSV.File(
    filepath;
    typemap = Dict(Int64=>Float64, Int32=>Float64),
    types = Dict(:t=>Float64, :measurement=>Float64, :scope=>Symbol, :condition=>Symbol, :distribution=>Symbol),
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
  df[!,:scope] .= Symbol.(df[!,:scope])
  df[!,:condition] .= Symbol.(df[!,:condition])
  df[!,:distribution] .= Symbol.(df[!,:distribution])

  return df
end

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
  for f in ["t", "measurement", "scope", "condition", "distribution"]
    @assert f ∈ names_df "Required column name $f is not found in measurements table."
  end
  return nothing
end