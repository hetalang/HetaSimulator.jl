# paths to npm.cmd and nodejs.exe
const NPM_PATH = npm_cmd()
const NODE_PATH = dirname(nodejs_cmd().exec[1])

# default path and model file name
const MODEL_DIR = "_julia"
const MODEL_NAME = "model.jl"

"""
    heta_update(version::String)

Installs heta-compiler from NPM.
"""
heta_update() = run(`$NPM_PATH i heta-compiler --prefix $NODE_PATH/node_modules`)
# install particular version
heta_update(version::String) = run(`$NPM_PATH i heta-compiler@$version --prefix $NODE_PATH/node_modules`)
# install from GitHub's repository
heta_update_dev(branch::String = "master") = run(`$NPM_PATH i https://github.com/hetalang/heta-compiler.git\#$branch --prefix $NODE_PATH/node_modules`)

"""
    heta_build(  
      heta_index::AbstractString;
      declaration::String = "platform",
      skip_export::Bool = false,
      log_mode::String = "error",
      debug::Bool = false,
      julia_only::Bool = false,
      dist_dir::String = "dist",
      meta_dir::String = "meta",
      source::String = "index.heta",
      type::String = "heta"
    )

Builds the model from Heta-based reactions
"""
function heta_build(
  heta_index::AbstractString;
  declaration::String = "platform",
  skip_export::Bool = false,
  log_mode::String = "error",
  debug::Bool = false,
  julia_only::Bool = false,
  dist_dir::String = "dist",
  meta_dir::String = "meta",
  source::String = "index.heta",
  type::String = "heta"
)   
  # check if heta is installed
  readdir("$NODE_PATH")
  !isfile("$NODE_PATH/node_modules/heta") && throw("Heta compiler is not installed. Run `heta_update()` to install it.")

  # convert to absolute path
  _heta_index = abspath(heta_index)

  # check if the dir contains src, index.heta, platform.json
  #isdir("$_heta_index/src") && throw("src directory not found in $_heta_index")
  #!isfile("$_heta_index/index.heta") && throw("index.heta file not found in $_heta_index")
  #!isfile("$_heta_index/platform.json") && throw("platform.json file not found in $_heta_index")

  # cmd options supported by heta-compiler
  options_array = String[]

  declaration != "platform" && push!(options_array, "--declaration", declaration)
  skip_export && push!(options_array, "--skip-export")
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
    
  run_build = run(ignorestatus(`$NODE_PATH/node $NODE_PATH/node_modules/node_modules/heta-compiler/bin/heta-build.js $options_array $_heta_index`))
  return run_build.exitcode
end


"""
    load_platform(  
      heta_index::AbstractString;
      rm_out::Bool = true,
      julia_only::Bool = true, 
      dist_dir::String = ".",
      source::String = "index.heta",
      type::String = "heta",
      kwargs...
    )

Converts heta model to Julia and outputs platform type
"""
function load_platform(
  heta_index::AbstractString;
  rm_out::Bool = true,
  julia_only::Bool = true, 
  dist_dir::String = ".",
  source::String = "index.heta",
  type::String = "heta",
  kwargs...
)
  # convert heta model to julia 
  build_exitcode = heta_build(heta_index; julia_only, dist_dir, source, type, kwargs...)
    
  # check the exitcode (0 - success, 1 - failure) 
  build_exitcode == 1 && throw("Compilation errors. Likely there is an error in the code of the model. See logs")
    
  #convert to absolute path
  _heta_index = abspath(heta_index)

  # load model to Main
  return load_jlplatform("$_heta_index/$MODEL_DIR/$MODEL_NAME"; rm_out)
end

"""
    load_jlplatform(  
      model_jl::AbstractString; 
      rm_out::Bool = false
    )

Loads prebuild julia model as part of platform
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
function load_jlmodel(model_jl::AbstractString; rm_out::Bool = false)
  platform = load_jlplatform(model_jl; rm_out = rm_out)
  
  first_model = [values(platform.models)...][1]

  return first_model
end
