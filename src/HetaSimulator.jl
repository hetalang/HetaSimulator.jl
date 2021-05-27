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
  using Distributed
  # measurements 
  using CSV
  using XLSX
  #plots
  using RecipesBase

  const HetaSimulatorDir = dirname(Base.@__DIR__)

  include("types.jl")
  include("heta_connect.jl")
  include("utils.jl")
  include("events.jl")
  include("measurements.jl")
  include("ode_problem.jl")
  include("condition.jl")
  include("simulate.jl")
  include("saving.jl")
  include("solution_interface.jl")
  include("loss.jl")
  include("fit.jl")
  include("monte_carlo.jl")
  include("import_platform.jl")

  export heta_update, heta_update_dev, heta_build, load_platform, load_jlplatform, load_jlmodel
  export Platform, Model, Cond, Params
  export TimeEvent, CEvent, StopEvent
  export read_conditions, add_conditions!
  export read_measurements, add_measurements!
  export constants, observables, conditions, events_on, models # parameters, variables, dynamic, static
  export CVODE_BDF, CVODE_Adams
  export optim, obj
  export sim, mc
  export fit, loss
  export HetaSimulatorDir
  export update
  export read_mcvecs, status_summary
  export save_results
end
