# Functions to proccess parameters table for parameters estimation problem (fitting).
# Parameters table is based on PETab format: 
# https://petab.readthedocs.io/en/latest/documentation_data_format.html#id3

const PARAMS_FIELDS_DICT = Base.ImmutableDict(
  :parameter => Symbol, # parametersId
  :scale => Symbol,     # parameterScale
  :lower => Float64,    # lowerBound
  :upper => Float64,    # upperBound
  :nominal => Float64,  # nominalValue
  :estimate => Bool
)

const PARAMS_FIELDS_OPT_DICT = Base.ImmutableDict(
  :parameterName => Symbol,
)

# read parameters csv file and output DataFrame
function read_parameters(filepath::String; kwargs...)
  params_df = CSV.read(
    filepath, DataFrame;
    types = merge(PARAMS_FIELDS_DICT,PARAMS_FIELDS_OPT_DICT), kwargs...)
  assert_params(params_df, keys(PARAMS_FIELDS_DICT))
  return params_df
end

function assert_params(df, colnames)
  names_df = propertynames(df)
  for f in colnames
    @assert f ∈ names_df "Required column name \"$f\" is not found in the table."
  end
  return nothing
end

