using CSV
using Tar, CodecZlib
using JSON
using Dates, UUIDs, Pkg

const META_VERSION = 1

function Base.write(tar_gz_filename::String, sim::Vector{Pair{Symbol, HetaSimulator.MCResult}})
    #CSV.write(io::IO, sim |> DataFrame, delim=";")

    temp_dir = mktempdir()  # archive content
    temp_file, temp_io = mktemp() # tar file

    meta_dict = get_meta(sim)
    meta_JSON = JSON.json(meta_dict, 4)
    write("$temp_dir/meta.json", meta_JSON)

    for pair in sim
        id = first(pair)
        s = last(pair)
        CSV.write("$temp_dir/$id.csv", s |> DataFrame, delim=";")
    end

    Tar.create(temp_dir, temp_file)

    open(tar_gz_filename, "w") do gz
        tar_gz_stream = GzipCompressorStream(temp_io)
        write(gz, tar_gz_stream)
    end
    close(temp_io)

    rm(temp_dir, recursive = true)
    rm(temp_file)

    return tar_gz_filename;
end

function get_meta(sim::Vector{Pair{Symbol, HetaSimulator.MCResult}})
    meta_dict = Dict(
        :type => "MCResult",
        :write_date => Dates.now(),
        :uuid => string(UUIDs.uuid4()),
        :meta_version => META_VERSION,
        :heta_compiler_version => HetaSimulator.HETA_COMPILER_VERSION,
        :heta_simulator_version => string(Pkg.project().version),
        #:name => "mc-result-storage",
        #:models_path => nothing, # file model.jl of the platform

        :solver => Dict(
            :parameters_variation_path => "parameters.csv",
            :alg => "AutoTsit5(Rosenbrock23())",
            :abstol => 1e-06,
            :reltol => 1e-06,
            :options => Dict(),
            :parallel_type => "EnsembleSerial",
            :workers => 1,
            :threads => 1,
            :reduction_func => nothing
        ),
        :data => Dict()
    )

    return meta_dict
end
