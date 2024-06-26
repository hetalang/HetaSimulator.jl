module HetaSimulator

  # heta-compiler supported version
  const HETA_COMPILER_SUPPORTED = "0.8.4"
  const SUPPORTED_VERSIONS = ["0.8.4"]

  using Reexport
  
  # heta compiler support
  using NodeJS

  # diffeq-related pkgs
  using SciMLBase
  using SciMLBase.RecursiveArrayTools: VectorOfArray, vecarr_to_vectors, DiffEqArray, ArrayPartition #, NamedArrayPartition
  @reexport using SciMLBase.EnsembleAnalysis
  @reexport using OrdinaryDiffEq
  using Sundials

  # fitting
  using NLopt

  # utils
  using LabelledArrays
  using DataStructures
  @reexport using NaNMath
  @reexport using DataFrames
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

  const HetaSimulatorDir = dirname(Base.@__DIR__)

  include("types.jl")
  include("heta_cli/connect.jl")
  include("heta_cli/heta.jl")
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
  include("fit.jl")
  include("estimator.jl")
  include("monte_carlo.jl")
  include("ensemble_stats.jl")
  include("import_platform.jl")
  include("gsa.jl")
  include("save_as_heta.jl")
  include("heta_funcs.jl")
  
  heta_update()

  export heta, heta_help, heta_init, heta_update, heta_build
  export heta_update_dev, load_platform, load_jlplatform, load_jlmodel
  export Platform, Model, Scenario
  export read_scenarios, add_scenarios!
  export read_measurements, add_measurements!, measurements_as_table
  export read_parameters
  export models, scenarios, scenario, constants, records, switchers, events, parameters, events_active, events_save, observables  # variables, dynamic, static
  export measurements, tspan 
  export CVODE_BDF, CVODE_Adams
  export optim, obj
  export sim, mc, mc!
  export fit, loss, estimator
  export HetaSimulatorDir
  export update
  export times, vals, status, status_summary
  export save_results, read_mcvecs
  export gsa, pearson, partial, standard
  export save_as_heta
  export scale_params, unscale_params
  export piecewise
end
