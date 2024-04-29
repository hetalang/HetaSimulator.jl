# default path and model file name
const MODEL_DIR = "_julia"
const MODEL_NAME = "model.jl"

"""
    heta_update_dev(branch::String = "master")

Installs heta-compiler from GitHub's repository <https://github.com/hetalang/heta-compiler>.

Arguments:

- `branch` : branch to install, default is "master".  
"""
heta_update_dev(branch::String = "master") = run(`$NPM_PATH i -g https://github.com/hetalang/heta-compiler.git\#$branch --prefix $NODE_DIR`)

"""
    load_platform(  
      target_dir::AbstractString;
      rm_out::Bool = true,
      julia_only::Bool = true, 
      dist_dir::String = ".",
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
- `dist_dir` : directory path, where to write distributives to. Default is `"."`
- kwargs : other arguments supported by `heta_build`

"""
function load_platform(
  target_dir::AbstractString;
  rm_out::Bool = true,
  dist_dir::String = ".",
  kwargs...
)
  # convert heta model to julia 
  build_res = heta_build(target_dir; julia_only = true, dist_dir = dist_dir, kwargs...)
    
  # check the exitcode (0 - success, 1 - failure) 
  build_res == 1 && throw("Compilation errors. Likely there is an error in the code of the model. See logs")
    
  #convert to absolute path
  _target_dir = abspath(target_dir)

  # load model to Main
  return load_jlplatform("$_target_dir/$MODEL_DIR/$MODEL_NAME"; rm_out)
end

"""
    load_jlplatform(  
      model_jl::AbstractString; 
      rm_out::Bool = false
    )

Loads prebuild julia model as part of `Platform`

Arguments:

- `model_jl` : path to Julia model file
- `rm_out` : should the file with Julia model be removed after the model is loaded. Default is `false`
"""
function load_jlplatform(
  model_jl::AbstractString; 
  rm_out::Bool = false
)
  # load model to Main
  Base.include(Main, model_jl)

  # remove output after model load
  rm_out && rm(dirname("$model_jl"); force=true, recursive=true)
  
  # tmp fix to output model without task
  # (models, tasks,) = Base.invokelatest(Main.Platform)

  platform = Base.invokelatest(Platform, Main.__platform__...)

  return platform
end

# tmp solution to add model only
"""
    load_jlmodel(  
      model_jl::AbstractString; 
      rm_out::Bool = false
    )

Loads prebuild julia model without `Platform`

Arguments:

- `model_jl` : path to Julia model file
- `rm_out` : should the file with Julia model be removed after the model is loaded. Default is `false`
"""
function load_jlmodel(model_jl::AbstractString; rm_out::Bool = false)
  platform = load_jlplatform(model_jl; rm_out = rm_out)
  
  first_model = [values(platform.models)...][1]

  return first_model
end

"""
    load_mtkmodel(  
      model_jl::AbstractString; 
    )

Loads prebuild julia MTK model 

Arguments:

- `model_jl` : path to Julia MTK model file
"""
function load_mtkmodel(
  model_jl::AbstractString
)
  # load model to Main
  Base.include(Main, model_jl)
  
  return Base.invokelatest(MtkModel, Main.__model__...)
end