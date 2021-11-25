using Dates

"""
  save_as_heta(filepath::String, fr::FitResult)

Save fitting results in the Heta-formatted file.

Arguments

- `filepath` : file to save. The ".heta" extension is usually used.
- `fr` : fitting results.
"""
function save_as_heta(filepath::String, data; append = true)
  mode = append ? "a" : "w"
  open(filepath, mode) do io
    save_as_heta(io, data)
    println(io, "")
  end
end

function save_as_heta(io::IO, fr::FitResult)
  time = Dates.format(now(), "yyyy-mm-dd at HH:MM:SS")
  println(io, "// FitResult by HetaSimulator, saved $time")
  println(io, "// status: :$(fr.status), OF count: $(fr.numevals), OF value: $(fr.obj)")
  save_as_heta(io, optim(fr))
end

function save_as_heta(io::IO, parameters::Vector{Pair{Symbol,Float64}})
  for op in parameters
    println(io, "$(first(op)) = $(last(op));")
  end
end

function save_as_heta(io::IO, parameters::NamedTuple) # TODO: NamedTuple should be clarified
  for op in keys(parameters)
    println(io, "$(op) = $(parameters[op]);")
  end
end
