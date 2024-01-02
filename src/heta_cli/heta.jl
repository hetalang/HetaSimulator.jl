# paths to npm.cmd and nodejs.exe
const NPM_PATH = npm_cmd()
const NODE_DIR = dirname(nodejs_cmd().exec[1])
const HETA_PATH = Sys.iswindows() ? "$NODE_DIR/node_modules/heta-compiler" : "$NODE_DIR/lib/node_modules/heta-compiler"

"""
    heta(;version::Bool=false, help::Bool=false)

Run `heta` command in console.

Arguments:

- `version`: `true` if only heta-compiler version  is required
- `help`: `true` if CLI help wanted

"""
function heta(;version::Bool=false, help::Bool=false)
    # cmd options supported by heta-compiler
    options_array = String[]
    version != false && push!(options_array, "--version")
    help != false && push!(options_array, "--help")
    
    run_build = run(ignorestatus(`$NODE_DIR/node $HETA_PATH/bin/heta.js $options_array`))
    return run_build.exitcode
end

"""
    heta_help(command::String)

Display help for heta-compiler CLI

Arguments:

- `command`: command to display

"""

function heta_help(command::String)
    run_build = run(ignorestatus(`$NODE_DIR/node $HETA_PATH/bin/heta.js help $command`))
    return run_build.exitcode
end

"""
    heta_init(dir::String; force::Bool=false, silent::Bool=false)

Run initialization of the platform

Argument:

- `dir`: platform directory
- `force`: if `true` then replace files and directories
- `silent`: if `true` create with default options without prompt

"""
function heta_init(dir::String; force::Bool=false, silent::Bool=false)
    options_array = String[]
    force != false && push!(options_array, "--force")
    silent != false && push!(options_array, "--silent")

    run_build = run(ignorestatus(`$NODE_DIR/node $HETA_PATH/bin/heta-init.js $options_array $dir`))
    return run_build.exitcode
end

"""
    heta_update(version::String = HETA_COMPILER_SUPPORTED)

To install or update heta-compiler from NPM.

Arguments:

- `version` : `heta compiler` version. If the value is not provided, `heta_update` installs
   the latest version of `heta compiler` compartible with HetaSimulator.
"""
function heta_update(version::String=HETA_COMPILER_SUPPORTED)
    # XXX: Do we need to check if version in SUPPORTED_VERSIONS
    run_build = run(`$NPM_PATH i -g heta-compiler@$version --prefix $NODE_DIR`)
    return run_build.exitcode
end

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

Builds the models from Heta-based platform

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

  !isdir(HETA_PATH) && throw("Heta compiler is not installed. Run `heta_update()` to install it.")

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
  push!(options_array, "--skip-updates")

  # build the dist
  #=
  if  Sys.iswindows() 
    heta_cmd = "heta.cmd"
  else
    heta_cmd = "heta" # not tested on unix
  end
  =#

  run_build = run(ignorestatus(`$NODE_DIR/node $HETA_PATH/bin/heta-build.js $options_array $_target_dir`))

  return run_build.exitcode
end
