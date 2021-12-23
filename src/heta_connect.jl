# paths to npm.cmd and nodejs.exe
const NPM_PATH = npm_cmd()
const NODE_DIR = dirname(nodejs_cmd().exec[1])

# default path and model file name
const MODEL_DIR = "_julia"
const MODEL_NAME = "model.jl"

"""
    heta_update(version::String)

To install or update heta-compiler from NPM.

Arguments:

- `version` : `heta compiler` version. If the value is not provided, `heta_update` installs the latest version of `heta compiler` 
"""
heta_update() = run(`$NPM_PATH i -g heta-compiler --prefix $NODE_DIR`)
# install particular version
heta_update(version::String) = run(`$NPM_PATH i -g heta-compiler@$version --prefix $NODE_DIR`)
# install from GitHub's repository

"""
    heta_update_dev(branch::String = "master")

Installs heta-compiler from GitHub's repository <https://github.com/hetalang/heta-compiler>.

Arguments:

- `branch` : branch to install, default is "master".  
"""
heta_update_dev(branch::String = "master") = run(`$NPM_PATH i -g https://github.com/hetalang/heta-compiler.git\#$branch --prefix $NODE_DIR`)

"""
    heta_build(
      target_dir::AbstractString;
      declaration::String = "platform",
      skip_export::Bool = false,
      units_check::Bool = false,
      log_mode::String = "error",
      debug::Bool = false,
      julia_only::Bool = false,
      dist_dir::String = "dist",
      meta_dir::String = "meta",
      source::String = "index.heta",
      type::String = "heta"
    )

Builds the model from Heta-based reactions

See `heta comiler` docs for details:
https://hetalang.github.io/#/heta-compiler/cli-references?id=running-build-with-cli-options

Arguments:

- `target_dir` : path to a Heta platform directory
- `declaration` : path to declaration file. Default is `"platform"`
- `skip_export` : if set to `true` no files will be created. Default is `false`
- `units_check` : if set to `true` units will be checked for the consistancy
- `log_mode` : log mode. Default is `"error"`
- `debug` : turn on debug mode. Default is `false`
- `julia_only` : export only julia-based model. Default is `false`
- `dist_dir` : directory path, where to write distributives to. Default is `"dist"`
- `meta_dir` : meta directory path. Default is `"meta"`
- `source` : path to the main heta module. Default is `"index.heta"`
- `type` : type of the source file. Default is `"heta"`
"""
function heta_build(
  target_dir::AbstractString;
  declaration::String = "platform",
  skip_export::Bool = false,
  units_check::Bool = false,
  log_mode::String = "error",
  debug::Bool = false,
  julia_only::Bool = false,
  dist_dir::String = "dist",
  meta_dir::String = "meta",
  source::String = "index.heta",
  type::String = "heta"
)   
  # check if heta is installed
  heta_build_path = Sys.iswindows() ? "$NODE_DIR/node_modules/heta-compiler" : "$NODE_DIR/lib/node_modules/heta-compiler"

  !isdir(heta_build_path) && throw("Heta compiler is not installed. Run `heta_update()` to install it.")

  # convert to absolute path
  _target_dir = abspath(target_dir)

  # check if the dir contains src, index.heta, platform.json
  #isdir("$_target_dir/src") && throw("src directory not found in $_target_dir")
  #!isfile("$_target_dir/index.heta") && throw("index.heta file not found in $_target_dir")
  #!isfile("$_target_dir/platform.json") && throw("platform.json file not found in $_target_dir")

  # cmd options supported by heta-compiler
  options_array = String[]

  declaration != "platform" && push!(options_array, "--declaration", declaration)
  skip_export && push!(options_array, "--skip-export")
  units_check && push!(options_array, "--units-check")
  log_mode != "error" && push!(options_array, "--log-mode", log_mode)
  debug && push!(options_array, "--debug")
  julia_only && push!(options_array, "--julia-only")
  dist_dir != "dist" && push!(options_array, "--dist-dir", dist_dir)
  meta_dir != "meta" && push!(options_array, "--meta-dir", meta_dir)
  source != "index.heta" && push!(options_array, "--source", source)
  type != "heta" && push!(options_array, "--type", type)

  # build the dist
  #=
  if  Sys.iswindows() 
    heta_cmd = "heta.cmd"
  else
    heta_cmd = "heta" # not tested on unix
  end
  =#

  run_build = run(ignorestatus(`$NODE_DIR/node $heta_build_path/bin/heta-build.js $options_array $_target_dir`))
  return run_build.exitcode
end


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
  build_exitcode = heta_build(target_dir; julia_only = true, dist_dir = dist_dir, kwargs...)
    
  # check the exitcode (0 - success, 1 - failure) 
  build_exitcode == 1 && throw("Compilation errors. Likely there is an error in the code of the model. See logs")
    
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
