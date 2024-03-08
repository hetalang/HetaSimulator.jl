# check keys in y before merge
function merge_strict(x::NamedTuple, y::NamedTuple)
  if length(y) > 0
    miss_keys = setdiff(keys(y), keys(x))
    !isempty(miss_keys) && @warn "Keys $(miss_keys) not found."
    # yidxs = findall(x->x ∉ keys(x), keys(y))
    # @assert isempty(yidxs) "Cannot merge elements with keys $(keys(y)[yidxs]) in strict mode."

    return merge(x, y)
  else 
    return x
  end
end

dictkeys(d::Dict) = (collect(keys(d))...,)
dictvalues(d::Dict) = (collect(values(d))...,)

#=
to_nt(d::Dict{Symbol,T}) where {T} =
    NamedTuple{dictkeys(d)}(dictvalues(d))
=#
typed(v::Number) = Float64(v)
function typed(v::AbstractString) 
  v_float = tryparse(Float64,v)
  ret = isnothing(v_float) ? Symbol(v) : v_float
  ret
end

typed(v::Symbol) = v

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
has_saveat(prob::SciMLBase.AbstractODEProblem) = !isempty(prob.kwargs[:callback].discrete_callbacks[1].affect!.saveat_cache) 
has_saveat(mcr::MCResult) = mcr.saveat

# auxilary method to update values in LVector
# TODO: not optimal method
# TODO: write for any number of pairs update(la::LArray, argv...)
function update(la::LArray, pairs::AbstractVector{Pair{Symbol, C}}) where C<:Real
  clone = copy(la)
  keys_la = keys(la)

  for (key, value) in pairs
    key ∉ keys_la && throw("key :$key is not found in LVector.")
    clone[key] = value
  end

  return clone
end

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

# tmp adding methods to ArrayPartition interface to support events
function Base.setindex!(A::ArrayPartition, X::AbstractArray, I::AbstractVector{Int})
  Base.@_propagate_inbounds_meta
  Base.@boundscheck Base.setindex_shape_check(X, length(I))
  Base.require_one_based_indexing(X)
  X′ = Base.unalias(A, X)
  I′ = Base.unalias(A, I)
  count = 1
  for i in I′
      @inbounds x = X′[count]
      A[i] = x
      count += 1
  end
  return A
end
