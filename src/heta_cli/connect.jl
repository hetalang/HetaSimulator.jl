# default path and model file name
const MODEL_DIR = "_julia"
const MODEL_NAME = "model.jl"

"""
    load_platform(  
      target_dir::AbstractString;
      rm_out::Bool = true,
      source::String = "index.heta",
      type::String = "heta",
      kwargs...
    )

Converts heta model to Julia and outputs `Platform` type.

See `heta comiler` docs for details:
https://hetalang.github.io/#/heta-compiler/cli-references?id=running-build-with-cli-options

Arguments:

- `target_dir` : path to a Heta platform directory
- `rm_out` : should the file with Julia model be removed after the model is loaded. Default is `true`
- kwargs : other arguments supported by `heta_build`

"""
function load_platform(
  target_dir::AbstractString;
  rm_out::Bool = true,
  spaceFilter::Union{String, Vector{Symbol}, Nothing} = nothing,
  kwargs...
)
  if spaceFilter isa Vector{Symbol}
    spaceFilter = "^(" * join(spaceFilter, "|") * ")\$"
  end

  export_ = isnothing(spaceFilter) ? "{format:Julia, filepath:$MODEL_DIR}" : "{format:Julia, filepath:$MODEL_DIR, spaceFilter:'$spaceFilter'}"
  # convert heta model to julia
  dist_dir = rm_out ? mktempdir() : abspath(target_dir) # absolute
  build_res = heta_build(target_dir; dist_dir = dist_dir, export_ = export_, kwargs...)
    
  # check the exitcode (0 - success, 1 - failure) 
  build_res == 1 && throw("Compilation errors. Likely there is an error in the code of the model. See logs")

  # load model to Main
  res = load_jlplatform("$dist_dir/$MODEL_DIR/$MODEL_NAME")

  if rm_out
    rm(dist_dir; force=true, recursive=true)
  end
    
  return res
end

"""
    load_jlplatform(  
      model_jl::AbstractString
    )

Loads prebuild julia model as part of `Platform`

Arguments:

- `model_jl` : path to Julia model file
"""
function load_jlplatform(
  model_jl::AbstractString
)

  # load model to Main
  Base.include(Main, model_jl)
  
  version = Main.__platform__[3]
  @assert version == HETA_COMPILER_VERSION "The model was build with Heta compiler v$version, which is not supported.\n"*
  "This HetaSimulator release includes Heta compiler v$HETA_COMPILER_VERSION. Please re-compile the model with HetaSimulator load_platform()."
  
  # tmp fix to output model without task
  # (models, tasks,) = Base.invokelatest(Main.Platform)

  platform = Base.invokelatest(Platform, Main.__platform__...)

  return platform
end

# tmp solution to add model only
"""
    load_jlmodel(  
      model_jl::AbstractString
    )

Loads prebuild julia model without `Platform`

Arguments:

- `model_jl` : path to Julia model file
"""
function load_jlmodel(model_jl::AbstractString)
  platform = load_jlplatform(model_jl)
  
  first_model = [values(platform.models)...][1]

  return first_model
end
