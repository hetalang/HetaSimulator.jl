################################## Platform ###########################################

struct QPlatform{M,C}
  models::Dict{Symbol,M}
  conditions::Dict{Symbol,C}
end

models(p::QPlatform) = p.models
conditions(p::QPlatform) = p.conditions

function Base.show(io::IO, ::MIME"text/plain", p::QPlatform)
  println(io, "Platform contains:")
  println(io, "  $(length(models(p))) model(s). Use `models(p::QPlatform)` for details.")
  println(io, "  $(length(conditions(p))) condition(s). Use `conditions(p::QPlatform)` for details.")
end

################################## Model ###########################################

abstract type AbstractModel end

struct QModel{IF,O,EV,SF,C} <: AbstractModel
  init_func::IF
  ode::O
  events::EV # Should it be inside of prob or not?
  saving_generator::SF
  observables::Vector{Symbol}
  constants::C # LArray{Float64,1,Array{Float64,1},(:a, :b)}
  events_on::Vector{Pair{Symbol,Bool}}
end

constants(m::QModel) = m.constants
events(m::QModel) = m.events_on
observables(m::QModel) = m.observables

function Base.show(io::IO, ::MIME"text/plain", m::QModel)
  println(io, "Model contains:")
  println(io, "  $(length(constants(m))) constant(s). Use `constants(m::QModel)` for details.")
  println(io, "  $(length(observables(m))) observable(s). Use `observables(m::QModel)` for details.")
  println(io, "  $(length(events(m))) event(s). Use `events(m::QModel)` for details.")
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

const MeasurementVector{P} = AbstractVector{P} where P<:AbstractMeasurementPoint

################################## Cond ###########################################

abstract type AbstractCond end

# TODO temporal mutable solution
mutable struct Cond{D,SF} <: AbstractCond
  model::QModel
  constants::Vector{Pair{Symbol,Float64}}
  events_on::Vector{Pair{Symbol,Bool}} # store here event to update
  measurements::D
  saveat::Union{Nothing,AbstractVector{T}} where T<:Real
  tspan::Union{Nothing,Tuple{S,S}} where S<:Real
  observables::Vector{Symbol} # list of condition-specific observables
  saving::SF # saving function for ODEProblem, created from observables
end 

constants(c::Cond) = c.constants
events(c::Cond) = c.events_on
observables(c::Cond) = c.observables
measurements(c::Cond) = c.measurements

function Base.show(io::IO, ::MIME"text/plain", c::Cond)
  println(io, "Condition contains:")
  println(io, "  saveat values: $(c.saveat)")
  println(io, "  tspan: $(c.tspan)")
  println(io)
  println(io, "  $(length(constants(c))) constant(s). Use `constants(c::Cond)` for details.")
  println(io, "  $(length(observables(c))) observable(s). Use `observables(c::Cond)` for details.")
  println(io, "  $(length(events(c))) event(s). Use `events(c::Cond)` for details.")
  println(io, "  $(length(measurements(c))) data measurement(s). Use `measurements(c::Cond)` for details.")
end

################################## SimResults ###########################################
abstract type AbstractResults end

struct SimResults{LA,T,V,C} <: AbstractResults
  title::Union{String,Nothing} # name::Union{Symbol,Nothing} 
  constants::LA
  t::T
  vals::V
  scope::Vector{Symbol} # do we need it?
  condition::C
end

function Base.show(io::IO, m::MIME"text/plain", S::SimResults)
  println(io, "Simulation results:")
  print(io,"t: ")
  show(io,m,S.t)
  println(io)
  print(io,"u: ")
  show(io,m,S.vals)
  println(io)
  println(io)
  println(io, "You can plot simulation results with `plot(sim::SimResults)` or convert them to DataFrame with `DataFrame(sim::SimResults)`")
end

function Base.show(io::IO, m::MIME"text/plain", V::Vector{S}) where S<:SimResults
  println(io, "Simulation results for $(length(V)) condition(s).") 
  println(io, "You can index simulated conditions with `sol[i]` or plot all conditions with `plot(sol::Vector{SimResults})`")
end

################################## Monte-Carlo Simulation ##############################

struct MCResults{T,V,C} <: AbstractResults
  title::Union{String,Nothing}
  t::T
  vals::V
  condition::C
end

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
  name::Symbol
  atStart::Bool
end

struct CEvent{F1,F2} <: AbstractEvent
  condition_func::F1
  affect_func::F2
  name::Symbol
  atStart::Bool
end

struct StopEvent{F1} <: AbstractEvent
  condition_func::F1
  name::Symbol
  atStart::Bool
end

################################## Fitting ###########################################

struct FitResults{L<:Real}
  obj::L
  optim::Vector{Pair{Symbol,Float64}}
  status::Symbol
end

function Base.show(io::IO, m::MIME"text/plain", F::FitResults)
  println(io, "Fitting results:")
  println(io, "  status: $(F.status)")
  println(io, "  optim: $(F.optim). Access optim estimate with `optim(f::FitResults)`")
  println(io, "  objective function value: $(F.obj). Access objective value with `obj(f::FitResults)`")
end

optim(f::FitResults) = f.optim
obj(f::FitResults) = f.obj
