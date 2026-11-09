"""
    load_platform(heta_dir; rm_out=true, spaceFilter=nothing, kwargs...)

Compile a Heta project with `import_heta_all` and store its native
`HetaODESystem`s in a `Platform`. Other keywords are passed to HetaImporter.
Set `rm_out=false` to retain compiler output in the project directory.
"""
function load_platform(heta_dir::AbstractString;
  rm_out::Bool=true,
  spaceFilter::Union{String,Vector{Symbol},Nothing}=nothing,
  kwargs...
)
  if rm_out
    return mktempdir() do build_dir
      Platform(import_heta_all(heta_dir; build_dir, spaceFilter, kwargs...))
    end
  end
  return Platform(import_heta_all(heta_dir; build_dir=abspath(heta_dir), spaceFilter, kwargs...))
end

Platform(systems::OrderedDict) = Platform(systems, OrderedDict{Symbol,Scenario}())
