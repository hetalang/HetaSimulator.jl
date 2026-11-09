################################## Platform ###########################################
"""
    struct Platform{M,C}
      models::Dict{Symbol,M}     # dictionary storing Models
      scenarios::Dict{Symbol,C} # dictionary storing Scenarios
    end

The main storage representing a modeling platform.
Typically HetaSimulator works with one platform object which can include several models and scenarios.

Usually a `Platform` is created based on Heta formatted files using [`load_platform`]{@ref}.

To get the platform content use methods: `models(platform)`, `scenarios(platform).
"""
struct Platform{M,C}
  models::OrderedDict{Symbol,M}
  scenarios::OrderedDict{Symbol,C}
end

models(p::Platform) = p.models
scenarios(p::Platform) = p.scenarios

function Base.show(io::IO, mime::MIME"text/plain", p::Platform)
  models_names = join(keys(p.models), ", ")
  scn_names = join(keys(p.scenarios), ", ")

  measurements_count = 0
  for (x, y) in scenarios(p)
    measurements_count += length(measurements(y))
  end

  println(io, "Platform with $(length(models(p))) model(s), $(length(scenarios(p))) scenario(s), $measurements_count measurement(s)")
  println(io, "   Models: $models_names")
  println(io, "   Scenarios: $scn_names")
end

################################## Model ###########################################

constants(m::HetaODESystem) = collect(keys(parameters(m).tunable))
records(m::HetaODESystem) = unique(vcat(states(m), collect(keys(observed(m))),
  collect(keys(parameters(m).derived)), collect(keys(parameters(m).discrete))))
states(m::HetaODESystem) = collect(keys(equations(m)))
switchers(m::HetaODESystem) = [id for group in events(m) for id in keys(group)]
events_active(m::HetaODESystem) = [id => event.is_active for group in events(m) for (id, event) in group]
events_save(m::HetaODESystem) = [id => (true, true) for id in switchers(m)]
observables(m::HetaODESystem) = copy(m.dynms.observables)

# auxilary function to display first n components of Vector or Tuple
function print_lim(x::Union{Vector, Tuple}, n::Int)
  first_n = ["$y" for y in first(x, n)]
  if length(x) > n
    push!(first_n, "...")
  elseif length(x) == 0
    return "-"
  end
  return join(first_n, ", ")
end

function print_lim(::Nothing, n::Int)
  return "-"
end

function print_lim(x::NamedTuple, n::Int)
  x_keys = keys(x)
  if length(x) > n
    string_array = ["$(x_keys[i])=$(x[i])" for i in 1:n]
    push!(string_array, "...")
  else
    string_array = ["$(x_keys[i])=$(x[i])" for i in 1:length(x)]
  end

  return "(" * join(string_array, ", ") * ")"
end

################################## Measurement ###########################################

# abstract type AbstractMeasurement end # not used
abstract type AbstractMeasurementPoint end

struct NormalMeasurementPoint{M,SD} <: AbstractMeasurementPoint
  t::Float64
  val::Float64
  μ::M
  σ::SD
  weight::Float64
end

struct LogNormalMeasurementPoint{M,SD} <: AbstractMeasurementPoint
  t::Float64
  val::Float64
  μ::M
  σ::SD
  weight::Float64
end

const MeasurementVector{P} = AbstractVector{P} where P<:AbstractMeasurementPoint

################################## Scenario ###########################################
abstract type AbstractScenario end

"""
  struct Scenario{P,M} <: AbstractScenario
    prob::P
    measurements::M
    tags::AbstractVector{Symbol}
    group::Union{Symbol,Nothing}
    parameters::NamedTuple
    observables::Vector{Symbol}
  end

  Type representing simulation conditions, i.e. model variant with updated parameters and outputs.

  To get the internal properties use methods: `tspan(scenario)`, `parameters(scenario)`, `measurements(scenario)`
"""
struct Scenario{P,M} <: AbstractScenario
  prob::P
  measurements::M
  tags::AbstractVector{Symbol}
  group::Union{Symbol,Nothing}
  parameters::NamedTuple
  observables::Vector{Symbol}
end

saveat(scn::Scenario) = get(scn.prob.kwargs, :saveat, Float64[])
tspan(scn::Scenario) = scn.prob.tspan
parameters(scn::Scenario) = scn.parameters # scn.prob.p
measurements(scn::Scenario) = scn.measurements
observables(scn::Scenario) = scn.observables
# events_active(scn::Scenario)
# events_save(scn::Scenario)

function Base.show(io::IO, mime::MIME"text/plain", scn::Scenario)
  parameters_str = print_lim(
    parameters(scn),
    10
    )
  measurements_count = length(measurements(scn))

  time_points_str = "for tspan=$(tspan(scn))"

  println(io, "Scenario $time_points_str")
  println(io, "    Time range (tspan): $(tspan(scn))")
  println(io, "    Parameters: $(parameters_str)")
  println(io, "    Number of measurement points: $(measurements_count)")
  #println(io, "    Tags: $(scn.tags)")
  if !isnothing(scn.group) 
    println(io, "    Group: :$(scn.group)")
  end
end

################################## SimResult ###########################################
abstract type AbstractResult end

struct Simulation{V}
  vals::V
  parameters::NamedTuple
  status::Symbol
end

# Native indexing evaluates observed expressions using the saved parameter history.
function Simulation(sol::SciMLBase.AbstractODESolution, params::NamedTuple, vars::Vector{Symbol})
  model_parameters = parameters(sol.prob.f.sys)
  parameter_ids = union(keys(model_parameters.tunable), keys(model_parameters.derived),
    keys(model_parameters.discrete))
  # Discrete parameters have their own event-time grid; sample them on the ODE
  # grid. Keep direct state/observed indexing to preserve duplicate event rows.
  columns = [id in parameter_ids ? [sol(t; idxs=id) for t in sol.t] : sol[id] for id in vars]
  T = isempty(columns) ? eltype(eltype(sol.u)) : promote_type(eltype.(columns)...)
  rows = [T[col[i] for col in columns] for i in eachindex(sol.t)]
  values = DiffEqArray(rows, copy(sol.t); variables=vars, independent_variables=[:t])
  return Simulation(values, params, Symbol(sol.retcode))
end

status(s::Simulation) = s.status
times(s::Simulation) = s.vals.t
vals(s::Simulation) = s.vals.u
parameters(s::Simulation) = s.parameters

@inline Base.length(s::Simulation) = length(s.vals.t)

# tmp fix to support https://github.com/SciML/SciMLBase.jl/blob/ccaba96f4d7e29e9980cd4cd7270086fc5e542d6/src/ensemble/ensemble_analysis.jl#L56
function Base.getproperty(s::Simulation, sym::Symbol)
  if sym == :t
    return s.vals.t
  else
    return getfield(s, sym)
  end
end

"""
    struct SimResult{S, C<:Scenario} <: AbstractResult
      sim::S
      scenario::C 
    end

Structure storing results from [`sim`]{@ref} method applied for one [`Scenario`]{@ref}.

To get the content use methods: `status(results)`, `times(results)`, `vals(results)`, `parameters(results)`, observables(results).

The results can be transformed using `DataFrame` method or visualized using `plot` method.
"""
struct SimResult{S, C<:Scenario} <: AbstractResult
  sim::S
  scenario::C
end

status(sr::SimResult) = status(sr.sim)
times(sr::SimResult) = times(sr.sim)
vals(sr::SimResult) = vals(sr.sim)
parameters(sr::SimResult) = parameters(sr.sim)
scenario_parameters(sr::SimResult) = parameters(sr.scenario)
measurements(sr::SimResult) = sr.scenario.measurements

@inline Base.length(sr::SimResult) = length(sr.sim)

function Base.show(io::IO, mime::MIME"text/plain", sr::SimResult)
  dim2 = length(observables(sr))
  dimentions_str = "$(length(sr))x$dim2"
  times_str = print_lim(times(sr), 10)
  outputs_str = print_lim(observables(sr), 10)
  parameters_str = print_lim(parameters(sr), 10)

  println(io, "$dimentions_str SimResult with status :$(status(sr)).")
  println(io, "    Solution status: $(status(sr))")
  println(io, "    Time points (times): $(times_str)")
  println(io, "    Observables (outputs): $(outputs_str)")
  println(io, "    Parameters: $(parameters_str)")
end

function Base.show(io::IO, mime::MIME"text/plain", srp::Pair{Symbol, S}, short::Bool = false) where S<:SimResult
  sr = last(srp)
  dim2 = length(observables(sr))
  dimentions_str = "$(length(sr))x$dim2"

  short || println(io, "Pair{Symbol, SimResult}")
  println(io, "    :$(first(srp)) => $dimentions_str SimResult with status :$(status(sr)).")
end

function Base.show(io::IO, mime::MIME"text/plain", vector::Vector{Pair{Symbol, S}}) where S<:SimResult
  println(io, "$(length(vector))-element Vector{Pair{Symbol, SimResult}}") 

  for x in vector
    show(io, mime, x, true)
  end
end

function Base.getindex(vector::Vector{Pair{Symbol, S}}, id::Symbol) where S<:SimResult
  ind = findfirst((x) -> first(x)===id, vector)
  if ind === nothing
    throw("Index :$id is not found.")
  else
    return vector[ind]
  end
end

################################## Monte-Carlo Simulation ##############################

"""
    struct MCResult{S,C} <: AbstractResult
      sim::S
      saveat::Bool
      scenario::C
    end

Structure storing results of [`mc`]{@ref} method applied for one `Scenario`.

To convert into tabular format, use `DataFrame` method.

The base visulaization can be done with `plot` method.
"""
struct MCResult{S,C} <: AbstractResult
  sim::S
  saveat::Bool
  scenario::C
  # converged
  # elapsed_time
end

@inline Base.length(mcr::MCResult) = length(mcr.sim)
parameters(mcr::MCResult) = [parameters(mcr[i]) for i in 1:length(mcr)]
vals(mcr::MCResult) = [vals(mcr[i]) for i in 1:length(mcr)]
status_summary(mcr::MCResult) = counter([s.status for s in mcr.sim])
scenario(mcres::MCResult) = mcres.scenario

function Base.show(io::IO, mime::MIME"text/plain", mcr::MCResult{Vector{S},C}, short::Bool = false) where {S<:Simulation, C}
  # dimentions
  dim0 = length(mcr)
  if mcr.saveat 
    dim1 = length(times(mcr.sim[1]))
  else
    dim1 = "?"
  end
  dim2 = length(mcr.sim[1]) # test only first Simulation
  dimentions_str = "$(dim0)x$(dim1)x$(dim2)"

  # other
  status_pairs = [":$(first(x)) x $(last(x))" for x in status_summary(mcr)]
  status = join(status_pairs, ", ")
  outputs_str = print_lim(observables(mcr.sim[1]), 10)
  parameters_1 = parameters(mcr.sim[1])
  parameters_str = isnothing(parameters_1) ? "-" : print_lim(keys(parameters_1), 10)
  
  println(io, "$(dimentions_str) MCResult with status $(status)" )
  if !short
    println(io, "    Solution status: $(status)")
    println(io, "    Observables (outputs): $(outputs_str)")
    println(io, "    Parameters: $(parameters_str)")
  end
end

function Base.show(io::IO, mime::MIME"text/plain", mcr::MCResult{S,C}, short::Bool = false) where {S, C}
  println(io, "Reduced MCResults" )
end

function Base.show(io::IO, mime::MIME"text/plain", mcrp::Pair{Symbol, S}, short=false) where S<:MCResult 
  short || println(io, "Pair{Symbol, MCResult}")
  print(io, "    :$(first(mcrp)) => ")
  Base.show(io, mime, last(mcrp), true)
end

function Base.show(io::IO, mime::MIME"text/plain", vector::Vector{Pair{Symbol, S}}) where S<:MCResult
  println(io, "$(length(vector))-element Vector{Pair{Symbol, MCResult}}") 

  for x in vector
    show(io, mime, x, true)
  end
end

function Base.getindex(V::Vector{Pair{Symbol, S}}, id::Symbol) where S<:MCResult
  ind = findfirst((x) -> first(x)===id, V)
  if ind === nothing
    throw("Index :$id is not found.")
  else
    return V[ind]
  end
end

################################## EnsembleSummary #####################################
struct LabelledEnsembleSummary{E}
  ens::E
  vars::Vector{Symbol}
end

observables(ens::LabelledEnsembleSummary) = ens.vars

Base.show(io::IO, mime::MIME"text/plain", ens::LabelledEnsembleSummary) = 
  println(io, "Summary statistics for the following observables: $(observables(ens))")

################################## Fitting ###########################################
"""
    struct FitResult{L<:Real, I}
      obj::L
      optim::Vector{Pair{Symbol,Float64}}
      status::Symbol
      numevals::I
    end

Result of [`fit`](@ref).

Use `optim` method to get optimal values.

Use `object` method to get optimal objective function.

Use `status` to get status.

The optimal parameters can be saved in heta file, see [`save_as_heta`](@ref) method.
"""
struct FitResult{L<:Real, I}
  obj::L
  optim::Vector{Pair{Symbol,Float64}}
  optim_scaled::Vector{Pair{Symbol,Float64}}
  status::Symbol
  numevals::I
end

function Base.show(io::IO, mime::MIME"text/plain", fr::FitResult)
  println(io, "FitResult with status :$(fr.status)")
  println(io, "   Status: $(fr.status)")
  println(io, "   Optimal values: $(fr.optim)")
  println(io, "   OF value: $(fr.obj)")
  println(io, "   OF count: $(fr.numevals)")
end

optim(f::FitResult) = f.optim
obj(f::FitResult) = f.obj
status(f::FitResult) = f.status
