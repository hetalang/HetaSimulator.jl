module HetaSimulator

  using Reexport
  
  # diffeq-related pkgs
  @reexport using HetaImporter
  using SciMLBase
  using SciMLBase.RecursiveArrayTools: VectorOfArray, vecarr_to_vectors, DiffEqArray, ArrayPartition, copyat_or_push! #, NamedArrayPartition
  @reexport using SciMLBase.EnsembleAnalysis
  @reexport using OrdinaryDiffEqBDF
  @reexport using OrdinaryDiffEqRosenbrock
  @reexport using OrdinaryDiffEqSDIRK
  @reexport using OrdinaryDiffEqTsit5
  using ADTypes: AutoForwardDiff, AutoFiniteDiff, AutoSparse
  using ForwardDiff
  # fitting
  @reexport using OptimizationNLopt

  # utils
  using LabelledArrays
  using DataStructures
  @reexport using NaNMath
  @reexport using DataFrames
  import DataFrames: DataFrame
  @reexport using Distributions
  using LinearAlgebra
  using Distributed
  using ProgressMeter
  #ProgressMeter.ijulia_behavior(:clear)

  # measurements 
  using CSV
  using XLSX

  #plots
  using RecipesBase

  const HetaSimulatorDir = dirname(@__DIR__)

  include("types.jl")
  include("load_platform.jl")
  include("utils.jl")
  include("events.jl")
  include("measurements.jl")
  include("ode_problem.jl")
  include("scenario.jl")
  include("parameters.jl")
  include("simulate.jl")
  include("saving.jl")
  include("solution_interface.jl")
  include("plots.jl")
  include("loss.jl")
  include("optprob.jl")
  include("fit.jl")
  include("estimator.jl")
  include("monte_carlo.jl")
  include("ensemble_stats.jl")
  include("import_platform.jl")
  include("save_as_heta.jl")
  include("heta_funcs.jl")


  export heta, heta_version, heta_help, heta_init, heta_build
  export load_platform, load_jlplatform, load_jlmodel
  export Platform, Model, Scenario
  export read_scenarios, add_scenarios!
  export read_measurements, add_measurements!, measurements_as_table
  export read_parameters
  export models, scenarios, scenario, constants, records, switchers, events, parameters, events_active, events_save, observables  # variables, dynamic, static
  export measurements, tspan 
  export optim, obj
  export sim, mc, mc!
  export fit, loss, estimator, generate_optimization_problem
  export HetaSimulatorDir
  export update
  export times, vals, status, status_summary
  export save_results, read_mcvecs
  export save_as_heta
  export scale_params, unscale_params
  export AutoForwardDiff, AutoFiniteDiff, AutoSparse
  export piecewise
end
