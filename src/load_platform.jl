"""
    load_platform(  
      heta_dir::AbstractString;
      rm_out::Bool = true,
      source::String = "index.heta",
      type::String = "heta",
      kwargs...
    )

Converts heta model to Julia and outputs `Platform` type.

See `heta comiler` docs for details:
https://hetalang.github.io/#/heta-compiler/cli-references?id=running-build-with-cli-options

Arguments:

- `heta_dir` : path to a Heta platform directory
- `rm_out` : should the file with Julia model be removed after the model is loaded. Default is `true`
- `ir_format` : format of the intermediate representation of the model. Default is `:julia`
- `spaceFilter` : filter for namespaces in the Heta model. Can be a string, a vector of symbols, or `nothing`. Default is `nothing`
- kwargs : other arguments supported by `heta_build`

"""
function load_platform(
  heta_dir::AbstractString;
  rm_out::Bool = true,
  ir_format::Symbol = :julia,
  spaceFilter::Union{String, Vector{Symbol}, Nothing} = nothing,
  kwargs...
)
  build_dir = rm_out ? mktempdir() : abspath(heta_dir)
  try
    julia_path = HetaImporter.build_julia_file(
      heta_dir;
      ir_format,
      build_dir,
      spaceFilter,
      kwargs...
    )

    return load_jlplatform(julia_path)
  finally
    _cleanup_build_dir(rm_out, build_dir)
  end
end

function _cleanup_build_dir(rm_out::Bool, build_dir::AbstractString)
  rm_out && !isempty(build_dir) && rm(build_dir; force=true, recursive=true)
  return nothing
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
  # include and CAPTURE the returned tuple (models, tasks, version)
  args = Base.invokelatest(() -> Base.include(Main, model_jl))

  # version check
  version = args[3]
  @assert version == HETA_COMPILER_VERSION "The model was build with Heta compiler v$version, which is not supported.\n"*
  "This HetaSimulator release includes Heta compiler v$HETA_COMPILER_VERSION. Please re-compile the model with HetaSimulator load_platform()."

  # build the Platform using the returned tuple
  platform = Base.invokelatest(Platform, args...)
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
