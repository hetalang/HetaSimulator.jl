################################## Platform ###########################################
"""
    struct Platform{M,C}
      models::Dict{Symbol,M}     # dictionary storing Models
      scenarios::Dict{Symbol,C} # dictionary storing Scenarios
    end

The main storage representing a modeling platform.
Typically HetaSimulator works with one platform object which can include several models and scenarios.

Usually a `Platform` is created based on Heta formatted files using [`load_platform`]{@ref}.
"""
struct Platform{M,C}
  models::Dict{Symbol,M}
  scenarios::Dict{Symbol,C}
end

models(p::Platform) = p.models
scenarios(p::Platform) = p.scenarios

function Base.show(io::IO, ::MIME"text/plain", p::Platform)
  models_names = join(keys(p.models), ", ")
  scn_names = join(keys(p.scenarios), ", ")

  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Platform contains:")
  println(io, "|   $(length(models(p))) model(s): $models_names. Use `models(platform)` for details.")
  println(io, "|   $(length(scenarios(p))) scenario(s): $scn_names. Use `scenarios(platform)` for details.")
  println(io, "+---------------------------------------------------------------------------")
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

function Base.show(io::IO, ::MIME"text/plain", m::Model)
  # observables_names = join(obs(m), ", ")

  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Model contains:")
  println(io, "|   $(length(m.constants)) constant(s). Use constants(model) to get the list.")
  println(io, "|   $(length(m.records_output)) static, dynamic and rule record(s). Use `records(model)` to get the list.")
  println(io, "|   $(length(m.events)) switchers(s). Use `switchers(model)` to get the list.")
  println(io, "| Use the following methods to get the default options:")
  println(io, "|   - parameters(model)")
  println(io, "|   - events_active(model)")
  println(io, "|   - events_save(model)")
  println(io, "|   - observables(model) : $(observables(m))")
  println(io, "+---------------------------------------------------------------------------")
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

struct Scenario{F,P,M} <: AbstractScenario
  init_func::F
  prob::P
  measurements::M
end 

saveat(c::Scenario) = c.prob.kwargs[:callback].discrete_callbacks[1].affect!.saveat_cache
tspan(c::Scenario) = c.prob.tspan
parameters(c::Scenario) = c.prob.p.constants
measurements(c::Scenario) = c.measurements

function Base.show(io::IO, ::MIME"text/plain", c::Scenario)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Scenario contains:")
  println(io, "|   $(length(saveat(c))) saveat values: $(saveat(c)). Use `saveat(scenario)` for details.")
  println(io, "|   tspan: $(tspan(c)). Use `tspan(scenario)` for details.")
  println(io, "|   $(length(parameters(c))) parameters(s). Use `parameters(scenario)` for details.")
  println(io, "|   $(length(measurements(c))) measurement(s). Use `measurements(scenario)` for details.")
  #println(io, "|   $(length(events_active(c))) event(s). Use `events_active(c::Scenario)` for details.")
  #println(io, "|   $(length(events_save(c))) event(s). Use `events_save(c::Scenario)` for details.")
  #println(io, "|   $(length(observables(c))) observable(s). Use `observables(c::Scenario)` for details.")
  println(io, "+---------------------------------------------------------------------------")
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

struct Simulation{V,scopeType}
  vals::V
  scope::scopeType
  status::Symbol
end

# copy fix is tmp needed not to rewrite SavedValues with new simulation
Simulation(sv::SavedValues,status::Symbol) = Simulation(DiffEqBase.SciMLBase.DiffEqArray(copy(sv.u),copy(sv.t)),sv.scope,status) 

status(s::Simulation) = s.status
times(s::Simulation) = s.vals.t
vals(s::Simulation) = s.vals.u

@inline Base.length(S::Simulation) = length(S.vals.t)

"""
    struct SimResults{S, C<:Scenario} <: AbstractResults
      sim::S
      scenario::C 
    end

Structure storing results from [`sim`]{@ref} method applied for one [`Scenario`]{@ref}.
"""
struct SimResults{S, C<:Scenario} <: AbstractResults
  sim::S
  scenario::C 
end

status(s::SimResults) = status(s.sim)
times(s::SimResults) = times(s.sim)
vals(s::SimResults) = vals(s.sim)

@inline Base.length(S::SimResults) = length(S.sim)

function Base.show(io::IO, m::MIME"text/plain", S::SimResults)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Status :$(status(S)).")
  println(io, "| Use `DataFrame(sim)` to convert results to DataFrame.")
  println(io, "| Use `plot(sim)` to plot results.")
  println(io, "+---------------------------------------------------------------------------")
end
Base.show(io::IO, m::MIME"text/plain", PS::Pair{Symbol, S}) where S<:SimResults = Base.show(io, m, last(PS))

#= XXX: do we need it?
function Base.show(io::IO, m::MIME"text/plain", V::Vector{S}) where S<:SimResults
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Simulation results for $(length(V)) scenario(s).") 
  println(io, "| Use `sol[i]` to get th i-th component.")
  println(io, "+---------------------------------------------------------------------------")
end
=#
function Base.show(io::IO, m::MIME"text/plain", V::Vector{Pair{Symbol, S}}) where S<:SimResults
  show_string = [*(":", String(x), " => ...") for x in first.(V)]
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Simulation results for $(length(V)) scenario(s).") 
  println(io, "| [$(join(show_string, ", "))]")
  println(io, "| Use `sol[id]` to get component by id.")
  println(io, "| Use `sol[i]` to get component by number.")
  println(io, "| Use `DataFrame(sol)` to transform.")
  println(io, "| Use `plot(sol)` to plot results.")
  println(io, "+---------------------------------------------------------------------------")
end

function Base.getindex(V::Vector{Pair{Symbol, S}}, id::Symbol) where S<:SimResults
  ind = findfirst((x) -> first(x)===id, V)
  if ind === nothing
    throw("Index :$id is not found.")
  else
    return V[ind]
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
