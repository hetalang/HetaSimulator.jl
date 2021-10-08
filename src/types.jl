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

function Base.show(io::IO, ::MIME"text/plain", p::Platform)
  models_names = join(keys(p.models), ", ")
  scn_names = join(keys(p.scenarios), ", ")

  measurements_count = 0
  for (x, y) in scenarios(p)
    measurements_count += length(measurements(y))
  end

  println(io, "Platform with $(length(models(p))) models, $(length(scenarios(p))) scenarios, $measurements_count measurements")
  println(io, "   Models: $models_names")
  println(io, "   Scenarios: $scn_names")
end

################################## Model ###########################################

abstract type AbstractModel end

"""
    struct Model{IF,OF,EV,SG,C,EA} <: AbstractModel
      init_func::IF
      ode_func::OF
      events::EV
      saving_generator::SG
      records_output::AbstractVector{Pair{Symbol,Bool}}
      constants::C
      events_active::EA
    end

Structure storing core properties of ODE model.
This represent the content of one namespace from a Heta platform.

To get list of model content use methods: constants(model), records(model), switchers(model).

To get the default model options use methods: `parameters(model)`, 
`events_active(model)`, `events_save(model)`, `observables(model)`.
These options can be rewritten by a [`Scenario`]{@ref}.
"""
struct Model{IF,OF,EV,SG,C,EA} <: AbstractModel
  init_func::IF
  ode_func::OF
  events::EV # IDEA: use (:TimeEvent, ...) instead of TimeEvent(...)
  saving_generator::SG
  records_output::AbstractVector{Pair{Symbol,Bool}}
  constants::C # LArray{Float64,1,Array{Float64,1},(:a, :b)}
  events_active::EA
end

constants(m::Model) = [keys(m.constants)...]
records(m::Model) = first.(m.records_output)
switchers(m::Model) = [keys(m.events)...]

parameters(m::Model) = collect(Pair{Symbol, Real}, pairs(m.constants))
events_active(m::Model) = collect(Pair{Symbol, Bool}, pairs(m.events_active))
events_save(m::Model) = [first(x) => (true,true) for x in pairs(m.events)]
observables(m::Model) = begin # observables
  only_true = filter((p) -> last(p), m.records_output)
  first.(only_true)
end

# auxilary function to display first n components of vector
function print_lim(x::Union{Vector, Tuple}, n::Int)
  first_n = ["$y" for y in first(x, n)]
  if length(x) > n
    push!(first_n, "...")
  end
  return join(first_n, ", ")
end
function print_lim(::Nothing, n::Int)
  return "-"
end

function Base.show(io::IO, ::MIME"text/plain", m::Model)
  const_str = print_lim(constants(m), 10)
  record_str = print_lim(records(m), 10)
  switchers_str = print_lim(switchers(m), 10)

  println(io, "Model containing $(length(m.constants)) constants, $(length(m.records_output)) records, $(length(m.events)) switchers.")
  println(io, "   Constants: $const_str")
  println(io, "   Records: $record_str")
  println(io, "   Switchers (events): $switchers_str")
end

################################## Params ###########################################

struct Params{C,S}
  constants::C 
  static::S
end

################################## Measurement ###########################################

# abstract type AbstractMeasurement end # not used
abstract type AbstractMeasurementPoint end

struct NormalMeasurementPoint{M,SD} <: AbstractMeasurementPoint
  t::Float64
  val::Float64
  scope::Symbol
  μ::M
  σ::SD
end

NormalMeasurementPoint(t,val,scope::Missing,μ,σ) = NormalMeasurementPoint(t,val,:ode_,μ,σ)

struct LogNormalMeasurementPoint{M,SD} <: AbstractMeasurementPoint
  t::Float64
  val::Float64
  scope::Symbol
  μ::M
  σ::SD
end

LogNormalMeasurementPoint(t,val,scope::Missing,μ,σ) = LogNormalMeasurementPoint(t,val,:ode_,μ,σ)

const MeasurementVector{P} = AbstractVector{P} where P<:AbstractMeasurementPoint

################################## Scenario ###########################################
abstract type AbstractScenario end

"""
  struct Scenario{F,P,M} <: AbstractScenario
    init_func::F
    prob::P
    measurements::M
  end

  Type representing simulation conditions, i.e. model variant with updated constants and outputs.

  To get the internal properties use methods: `saveat(scenario)`, `tspan(scenario)`, `parameters(scenario)`, `measurements(scenario)`
"""
struct Scenario{F,P,M} <: AbstractScenario
  init_func::F
  prob::P
  measurements::M
end 

saveat(scn::Scenario) = scn.prob.kwargs[:callback].discrete_callbacks[1].affect!.saveat_cache
tspan(scn::Scenario) = scn.prob.tspan
parameters(scn::Scenario) = scn.prob.p.constants
measurements(scn::Scenario) = scn.measurements
# events_active(scn::Scenario)
# events_save(scn::Scenario)
# observables(scn::Scenario)

function Base.show(io::IO, ::MIME"text/plain", scn::Scenario)
  saveat_str = print_lim(saveat(scn), 10)
  parameters_str = print_lim(
    keys(parameters(scn)),
    10
    )
  measurements_count = length(measurements(scn))

  if length(saveat(scn)) == 0
    time_points_str = "for tspan=$(tspan(scn))"
  else
    time_points_str = "for saveat=$(saveat_str)"
  end

  println(io, "Scenario $time_points_str")
  println(io, "   Time range (tspan): $(tspan(scn))")
  println(io, "   Exact time points (saveat): $(saveat_str)")
  println(io, "   Parameters: $(parameters_str)")
  println(io, "   Measurement points count: $(measurements_count)")
end

################################## SimResults ###########################################
abstract type AbstractResults end

struct SavedValues{uType,tType,scopeType}
  u::uType
  t::tType
  scope::scopeType
end

function clear_savings(sv::SavedValues)
  !isempty(sv.u) && deleteat!(sv.u,1:length(sv.u))
  !isempty(sv.t) && deleteat!(sv.t,1:length(sv.t))
  !isnothing(sv.scope) && !isempty(sv.scope) && deleteat!(sv.scope,1:length(sv.scope))
  return nothing
end

struct Simulation{V,scopeType,P}
  vals::V
  scope::scopeType
  params::P
  status::Symbol
end

# copy fix is tmp needed not to rewrite SavedValues with new simulation
Simulation(sv::SavedValues, params, status::Symbol) = Simulation(
  DiffEqBase.SciMLBase.DiffEqArray(copy(sv.u),copy(sv.t)),
  sv.scope,
  params,
  status
) 

status(s::Simulation) = s.status
times(s::Simulation) = s.vals.t
vals(s::Simulation) = s.vals.u
parameters(s::Simulation) = s.params

@inline Base.length(S::Simulation) = length(S.vals.t)

# tmp fix to support https://github.com/SciML/SciMLBase.jl/blob/ccaba96f4d7e29e9980cd4cd7270086fc5e542d6/src/ensemble/ensemble_analysis.jl#L56
function Base.getproperty(s::Simulation, sym::Symbol)
  if sym == :t
    return s.vals.t
  else
    return getfield(s, sym)
  end
end

"""
    struct SimResults{S, C<:Scenario} <: AbstractResults
      sim::S
      scenario::C 
    end

Structure storing results from [`sim`]{@ref} method applied for one [`Scenario`]{@ref}.

To get the content use methods: `status(results)`, `times(results)`, `vals(results)`, `parameters(results)`, observables(results).

The results can be transformed using `DataFrame` method or visualized using `plot` method.
"""
struct SimResults{S, C<:Scenario} <: AbstractResults
  sim::S
  scenario::C 
end

status(sr::SimResults) = status(sr.sim)
times(sr::SimResults) = times(sr.sim)
vals(sr::SimResults) = vals(sr.sim)
parameters(sr::SimResults) = parameters(sr.sim) # XXX: check here, maybe better is parameters(sr.scenario)
observables(sr::SimResults) = [keys(vals(sr.sim)[1])...]

@inline Base.length(sr::SimResults) = length(sr.sim)

function Base.show(io::IO, m::MIME"text/plain", sr::SimResults)
  dim2 = length(keys(sr.sim[1])) # number of observables
  dimentions_str = "$(length(sr))x$dim2"
  times_str = print_lim(times(sr), 10)
  outputs_str = print_lim(observables(sr), 10)
  parameters_str = print_lim(parameters(sr), 10)

  println(io, "$dimentions_str SimResults with status :$(status(sr)).")
  println(io, "    Solution status: $(status(sr))")
  println(io, "    Time points (times): $(times_str)")
  println(io, "    Observables (outputs): $(outputs_str)")
  println(io, "    Parameters: $(parameters_str)")
end

function Base.show(io::IO, m::MIME"text/plain", srp::Pair{Symbol, S}, short::Bool = false) where S<:SimResults
  sr = last(srp)
  dim2 = length(keys(sr.sim[1])) # number of observables
  dimentions_str = "$(length(sr))x$dim2"

  short || println(io, "Pair{Symbol, SimResults}")
  println(io, "    :$(first(srp)) => $dimentions_str SimResults with status :$(status(sr)).")
end

function Base.show(io::IO, m::MIME"text/plain", vector::Vector{Pair{Symbol, S}}) where S<:SimResults
  println(io, "$(length(vector))-element Vector{Pair{Symbol, SimResults}}") 

  for x in vector
    show(io, m, x, true)
  end
end

function Base.getindex(vector::Vector{Pair{Symbol, S}}, id::Symbol) where S<:SimResults
  ind = findfirst((x) -> first(x)===id, vector)
  if ind === nothing
    throw("Index :$id is not found.")
  else
    return vector[ind]
  end
end

################################## Monte-Carlo Simulation ##############################

"""
    struct MCResults{S,C} <: AbstractResults
      sim::S
      saveat::Bool
      scenario::C
    end

Structure storing results of [`mc`]{@ref} method applied for one `Scenario`.
"""
struct MCResults{S,C} <: AbstractResults
  sim::S
  saveat::Bool
  scenario::C
  # converged
  # elapsed_time
end

@inline Base.length(S::MCResults) = length(S.sim)
status_summary(MC::MCResults) = counter([sim.status for sim in MC])

function Base.show(io::IO, m::MIME"text/plain", MC::MCResults)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Monte-Carlo results for $(length(MC)) iterations." )
  println(io, "| Use `plot(sol::MCResults)` to plot results.")
  println(io, "+---------------------------------------------------------------------------")
end

Base.show(io::IO, m::MIME"text/plain", PS::Pair{Symbol, S}) where S<:MCResults = Base.show(io, m, last(PS))
#= XXX: do we need it?
function Base.show(io::IO, m::MIME"text/plain", VMC::Vector{MC}) where MC<:MCResults
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Monte-Carlo results for $(length(VMC)) scenario(s).") 
  println(io, "| Use `sol[i]` to index Monte-Carlo results.")
  println(io, "+---------------------------------------------------------------------------")
end
=#
function Base.show(io::IO, m::MIME"text/plain", VMC::Vector{Pair{Symbol, S}}) where S<:MCResults
  show_string = [*(":", String(x), " => ...") for x in first.(VMC)]
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Monte-Carlo results for $(length(VMC)) scenario(s).") 
  println(io, "| [$(join(show_string, ", "))]")
  println(io, "| Use `sol[id]` to get component by id.")
  println(io, "| Use `sol[i]` to get component by number.")
  println(io, "| Use `DataFrame(sol)` to transform.")
  println(io, "| Use `plot(sol)` to plot results.")
  println(io, "+---------------------------------------------------------------------------")
end
function Base.getindex(V::Vector{Pair{Symbol, S}}, id::Symbol) where S<:MCResults
  ind = findfirst((x) -> first(x)===id, V)
  if ind === nothing
    throw("Index :$id is not found.")
  else
    return V[ind]
  end
end

################################## Events ##############################################
abstract type AbstractEvent end

struct TimeEvent{F1,F2} <: AbstractEvent
  condition_func::F1
  affect_func::F2
  atStart::Bool
end

struct CEvent{F1,F2} <: AbstractEvent
  condition_func::F1
  affect_func::F2
  atStart::Bool
end

struct StopEvent{F1} <: AbstractEvent
  condition_func::F1
  atStart::Bool
end

################################## Fitting ###########################################

struct FitResults{L<:Real, I}
  obj::L
  optim::Vector{Pair{Symbol,Float64}}
  status::Symbol
  numevals::I
end

function Base.show(io::IO, m::MIME"text/plain", F::FitResults)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Fitting results:")
  println(io, "|   status: $(F.status)")
  println(io, "|   optim: $(F.optim). Access optim estimate with `optim(f::FitResults)`")
  println(io, "|   objective function value: $(F.obj). Access objective value with `obj(f::FitResults)`")
  println(io, "|   number of objective function evaluations: $(F.numevals)")
  println(io, "+---------------------------------------------------------------------------")
end

optim(f::FitResults) = f.optim
obj(f::FitResults) = f.obj
status(f::FitResults) = f.status
