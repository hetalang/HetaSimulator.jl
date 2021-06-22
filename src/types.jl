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

struct Cond{F,P,M} <: AbstractCond
  init_func::F
  prob::P
  measurements::M
end 

saveat(c::Cond) = c.prob.kwargs[:callback].discrete_callbacks[1].affect!.saveat.valtree
tspan(c::Cond) = c.prob.tspan
parameters(c::Cond) = c.prob.p.constants
measurements(c::Cond) = c.measurements

function Base.show(io::IO, ::MIME"text/plain", c::Cond)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Cond contains:")
  println(io, "|   $(length(saveat(c))) saveat values: $(saveat(c)). Use `saveat(cond)` for details.")
  println(io, "|   tspan: $(tspan(c)). Use `tspan(cond)` for details.")
  println(io, "|   $(length(parameters(c))) parameters(s). Use `parameters(cond)` for details.")
  println(io, "|   $(length(measurements(c))) measurement(s). Use `measurements(cond)` for details.")
  #println(io, "|   $(length(events_active(c))) event(s). Use `events_active(c::Cond)` for details.")
  #println(io, "|   $(length(events_save(c))) event(s). Use `events_save(c::Cond)` for details.")
  #println(io, "|   $(length(observables(c))) observable(s). Use `observables(c::Cond)` for details.")
  println(io, "+---------------------------------------------------------------------------")
end

################################## SimResults ###########################################
abstract type AbstractResults end

struct SavedValues{uType,tType,scopeType}
  u::uType
  t::tType
  scope::scopeType
end

struct Simulation{V,scopeType}
  vals::V
  scope::scopeType
  status::Symbol
end

Simulation(sv::SavedValues,status::Symbol) = Simulation(DiffEqBase.SciMLBase.DiffEqArray(sv.u,sv.t),sv.scope,status)

struct SimResults{S, C<:Cond} <: AbstractResults
  sim::S
  cond::C 
end

@inline Base.length(S::SimResults) = length(S.sim.u)

function Base.show(io::IO, m::MIME"text/plain", S::SimResults)
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Status :$(S.sim.status).")
  println(io, "| Use `DataFrame(sim)` to convert.")
  # show(io, m, DataFrame(S))
  println(io, "+---------------------------------------------------------------------------")
end

function Base.show(io::IO, m::MIME"text/plain", V::Vector{S}) where S<:SimResults
  println(io, "+---------------------------------------------------------------------------")
  println(io, "| Simulation results for $(length(V)) condition(s).") 
  println(io, "| To get th i-th component use `sol[i]`")
  println(io, "+---------------------------------------------------------------------------")
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
  println(io, "Monte-Carlo results for $(length(MC)) iterations. You can plot results with `plot(sol::MCResults)`")
end

function Base.show(io::IO, m::MIME"text/plain", VMC::Vector{MC}) where MC<:MCResults
  println(io, "Monte-Carlo results for $(length(VMC)) condition(s).") 
  println(io, "You can index simulated Monte-Carlo conditions with `sol[i]` or plot all conditions with `plot(sol::Vector{MCResults})`")
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
