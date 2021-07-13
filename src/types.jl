################################## Platform ###########################################

struct Platform{M,C}
  models::Dict{Symbol,M}
  conditions::Dict{Symbol,C}
end

models(p::Platform) = p.models
conditions(p::Platform) = p.conditions

function Base.show(io::IO, ::MIME"text/plain", p::Platform)
  models_names = join(keys(p.models), ", ")
  conditions_names = join(keys(p.conditions), ", ")

  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Platform contains:")
  println(io, "|   $(length(models(p))) model(s): $models_names. Use `models(platform)` for details.")
  println(io, "|   $(length(conditions(p))) condition(s): $conditions_names. Use `conditions(platform)` for details.")
  println(io, "+---------------------------------------------------------------------------")
end

################################## Model ###########################################

abstract type AbstractModel end

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

const MeasurementVector{P} = AbstractVector{P} where P<:AbstractMeasurementPoint

################################## Condition ###########################################
abstract type AbstractCond end

struct Condition{F,P,M} <: AbstractCond
  init_func::F
  prob::P
  measurements::M
end 

saveat(c::Condition) = c.prob.kwargs[:callback].discrete_callbacks[1].affect!.saveat.valtree
tspan(c::Condition) = c.prob.tspan
parameters(c::Condition) = c.prob.p.constants
measurements(c::Condition) = c.measurements

function Base.show(io::IO, ::MIME"text/plain", c::Condition)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Condition contains:")
  println(io, "|   $(length(saveat(c))) saveat values: $(saveat(c)). Use `saveat(cond)` for details.")
  println(io, "|   tspan: $(tspan(c)). Use `tspan(cond)` for details.")
  println(io, "|   $(length(parameters(c))) parameters(s). Use `parameters(cond)` for details.")
  println(io, "|   $(length(measurements(c))) measurement(s). Use `measurements(cond)` for details.")
  #println(io, "|   $(length(events_active(c))) event(s). Use `events_active(c::Condition)` for details.")
  #println(io, "|   $(length(events_save(c))) event(s). Use `events_save(c::Condition)` for details.")
  #println(io, "|   $(length(observables(c))) observable(s). Use `observables(c::Condition)` for details.")
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
  !isempty(sv.scope) && deleteat!(sv.scope,1:length(sv.scope))
  return nothing
end

struct Simulation{V,scopeType}
  vals::V
  scope::scopeType
  status::Symbol
end

@inline Base.length(S::Simulation) = length(S.vals.t)

Simulation(sv::SavedValues,status::Symbol) = Simulation(DiffEqBase.SciMLBase.DiffEqArray(sv.u,sv.t),sv.scope,status)

struct SimResults{S, C<:Condition} <: AbstractResults
  sim::S
  cond::C 
end

@inline Base.length(S::SimResults) = length(S.sim)

function Base.show(io::IO, m::MIME"text/plain", S::SimResults)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Status :$(S.sim.status).")
  println(io, "| Use `DataFrame(sim)` to convert results to DataFrame.")
  println(io, "| Use `plot(sim)` to plot results.")
  println(io, "+---------------------------------------------------------------------------")
end
Base.show(io::IO, m::MIME"text/plain", PS::Pair{Symbol, S}) where S<:SimResults = Base.show(io, m, last(PS))

#= XXX: do we need it?
function Base.show(io::IO, m::MIME"text/plain", V::Vector{S}) where S<:SimResults
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Simulation results for $(length(V)) condition(s).") 
  println(io, "| Use `sol[i]` to get th i-th component.")
  println(io, "+---------------------------------------------------------------------------")
end
=#
function Base.show(io::IO, m::MIME"text/plain", V::Vector{Pair{Symbol, S}}) where S<:SimResults
  show_string = [*(":", String(x), " => ...") for x in first.(V)]
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Simulation results for $(length(V)) condition(s).") 
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

struct MCResults{S,C} <: AbstractResults
  sim::S
  saveat::Bool
  cond::C
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
  println(io, "| Monte-Carlo results for $(length(VMC)) condition(s).") 
  println(io, "| Use `sol[i]` to index Monte-Carlo results.")
  println(io, "+---------------------------------------------------------------------------")
end
=#
function Base.show(io::IO, m::MIME"text/plain", VMC::Vector{Pair{Symbol, S}}) where S<:MCResults
  show_string = [*(":", String(x), " => ...") for x in first.(VMC)]
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Monte-Carlo results for $(length(VMC)) condition(s).") 
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
