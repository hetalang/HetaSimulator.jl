module HetaSimulator

  using Reexport
  
  # heta compiler support
  using Pkg.Artifacts
  import Base: SHA1

  # heta-compiler supported version
  const HETA_COMPILER_VERSION = "0.10.0"
  #const SUPPORTED_VERSIONS = ["0.8.4", "0.8.5", "0.8.6"]

  function heta_compiler_load()
    artifact_info = artifact_meta("heta_app", joinpath(@__DIR__, "..", "Artifacts.toml"))
  
    artifact_info === nothing && throw("Your arch/OS is not supported by heta-compiler. Please, report this issue to Heta development team.")
  
    return artifact_path(SHA1(artifact_info["git-tree-sha1"]))
  end
  
  const heta_path = heta_compiler_load()
  const heta_exe_name = Sys.iswindows() ? "heta-compiler.exe" : "heta-compiler" 
  const heta_exe_path = heta_path === nothing ? heta_exe_name : joinpath(heta_path, heta_exe_name)

  # diffeq-related pkgs
  using SciMLBase
  using SciMLBase.RecursiveArrayTools: VectorOfArray, vecarr_to_vectors, DiffEqArray, ArrayPartition, copyat_or_push! #, NamedArrayPartition
  @reexport using SciMLBase.EnsembleAnalysis
  @reexport using OrdinaryDiffEq
  using Sundials
  using ForwardDiff
  # fitting
  @reexport using OptimizationNLopt

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

  const HetaSimulatorDir = dirname(@__DIR__)

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
  export CVODE_BDF, CVODE_Adams
  export optim, obj
  export sim, mc, mc!
  export fit, loss, estimator, generate_optimization_problem
  export HetaSimulatorDir
  export update
  export times, vals, status, status_summary
  export save_results, read_mcvecs
  export save_as_heta
  export scale_params, unscale_params
  export piecewise
end
