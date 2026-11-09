# check keys in y before merge
function merge_strict(x::NamedTuple, y::NamedTuple)
  if length(y) > 0
    miss_keys = setdiff(keys(y), keys(x))
    !isempty(miss_keys) && @warn "Keys $(miss_keys) not found." maxlog=1
    # yidxs = findall(x->x ∉ keys(x), keys(y))
    # @assert isempty(yidxs) "Cannot merge elements with keys $(keys(y)[yidxs]) in strict mode."

    return merge(x, y)
  else 
    return x
  end
end

dictkeys(d::Dict) = (collect(keys(d))...,)
dictvalues(d::Dict) = (collect(values(d))...,)

# normalize values from DataFrame cells to correct types
# all Numbers to Float64
typed(v::Number) = Float64(v)
# all strings to Float64 if possible, otherwise to Symbol
typed(v::AbstractString) = something(tryparse(Float64, v), Symbol(v))
# all symbols to symbols
typed(v::Symbol) = v
# missing values to missing
typed(::Missing) = missing

function _subset(
  vector::AbstractVector,
  subset::AbstractVector{P} = Pair{Symbol, Symbol}[]
) where P <: Pair{Symbol, Symbol}
  if length(subset) === 0
    # use the whole vector
    return vector
  else
    # this function performs matching
    # returs true if all values in subset equal to values in row
    subset_fun = (row) -> begin
      res = [row[key] == value for (key, value) in subset]
      return all(res)
    end

    return filter(subset_fun, vector)
  end
end

has_saveat(c::Scenario) = has_saveat(c.prob)
has_saveat(prob::SciMLBase.AbstractODEProblem) = !isempty(get(prob.kwargs, :saveat, Float64[]))
has_saveat(mcr::MCResult) = mcr.saveat

update(p1::AbstractVector{P}, p2::AbstractVector{P}) where P<:Pair = update(Dict(p1),Dict(p2))

function update(d1::Dict, d2::Dict)
  d = copy(d1)
  keys_d = keys(d)

  for (k,v) in d2
    k ∉ keys_d && throw("key :$k is not found in Dict.")
    d[k] = v
  end

  return d
end

float64(n::Number) = Float64(n)
float64(m::Missing) = m

bool(i::Int) = Bool(i)
function bool(s::AbstractString) 
  s == "TRUE" && return true
  s == "FALSE" && return false
  return parse(Bool, s)
end
bool(b::Bool) = b

sanitizenames!(df::DataFrame) = rename!(df, strip.(names(df)))

function _to_float(x::Real)
    return float(x)
end

function _to_float(x::ForwardDiff.Dual)
    return float(x.value)
end
