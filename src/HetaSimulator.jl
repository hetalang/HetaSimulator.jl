module HetaSimulator

  using Reexport
  # heta compiler support
  using NodeJS
  # diffeq-related pkgs
  using LabelledArrays
  using DataStructures
  using DiffEqBase
  @reexport using OrdinaryDiffEq
  @reexport using DiffEqBase.EnsembleAnalysis
  using Sundials
  # fitting

  using NLopt
  # utils
  @reexport using DataFrames
  @reexport using Distributions
  # measurements 
  using CSV
  #plots
  using RecipesBase

  const HetaSimulatorDir = dirname(Base.@__DIR__)

  include("types.jl")
  include("heta_connect.jl")
  include("utils.jl")
  include("events.jl")
  include("measurements.jl")
  include("condition.jl")
  include("simulate.jl")
  include("ode_model.jl")
  include("saving.jl")
  include("solution_interface.jl")
  include("loss.jl")
  include("fit.jl")
  include("monte_carlo.jl")

  export heta_update, heta_update_dev, heta_build, load_platform, load_jlplatform, load_jlmodel
  export QPlatform, Model, Cond, Params
  export TimeEvent, CEvent, DEvent
  export read_conditions_csv, add_conditions!
  export read_measurements_csv, add_measurements!
  export constants, observables, conditions, events, models # parameters, variables, dynamic, static
  export optim, obj
  export sim, mc
  export fit, loss
  export HetaSimulatorDir
  export update
end
