using CSV
using Tar, CodecZlib
using JSON
using Dates, UUIDs, Pkg

const META_VERSION = 1

function Base.write(tar_gz_filename::String, sim::Vector{Pair{Symbol, HetaSimulator.MCResult}})
    #CSV.write(io::IO, sim |> DataFrame, delim=";")

    temp_dir = mktempdir()  # archive content
    temp_file, temp_io = mktemp() # tar file

    meta_dict = get_meta(tar_gz_filename, sim)
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

function get_meta(tar_gz_filename::String, sim::Vector{Pair{Symbol, HetaSimulator.MCResult}})
    meta_dict = Dict{Symbol,Any}(
        :type => "MCResult",
        :write_date => Dates.now(),
        :filename => tar_gz_filename,
        :uuid => UUIDs.uuid4() |> string,
        :meta_version => META_VERSION,
        :heta_compiler_version => HetaSimulator.HETA_COMPILER_VERSION,
        :heta_simulator_version => Pkg.project().version |> string,
        #:models_path => nothing, # file model.jl of the platform
        :csv_delimeter => ";",

        :solver => Dict{Symbol,Any}(
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
        :data => []
    )

    for pair in sim
        id = first(pair)
        s = last(pair)
        scenario = s.scenario
        prob = scenario.prob

        events = []
        for callback in prob.kwargs[:callback].discrete_callbacks[2:end]
            push!(events, Dict{Symbol,Any}(
                :id => callback.affect!.evt_name,
                :active => true,
                :atStart => callback.affect!.evt.atStart,
                :events_save => callback.affect!.events_save |> collect
            ))
        end

        push!(meta_dict[:data], Dict{Symbol,Any}(
            :id => id |> string,
            :simulation_path => "$id.csv",
            :model => Dict(
                #:id => "nameless"
            ),
            :scenario => Dict(
                :tspan => tspan(scenario) |> collect,
                :parameters => parameters(scenario) |> pairs |> Dict,
                :group => scenario.group,
                :tags => scenario.tags,
                :observables => observables(scenario) |> collect, # TODO: must be Dict(:id => "a", :output => true)
                :events => events
            )
            #=
            {
                "scenario": {
                    "observables": [
                        {"id": "comp1", "output": false},
                        {"id": "comp2", "output": false},
                        {"id": "a", "output": true},
                        {"id": "b", "output": true},
                        {"id": "c", "output": true},
                        {"id": "d", "output": true},
                        {"id": "r1", "output": false},
                        {"id": "r2", "output": false}
                    ],
                    "events": [
                        {"id": "sw1", "active": true, "save": true}
                    ],
                    "saveat": [50, 80, 150],
                    "save_scope": true,
                }
            }
            =#
        ))
    end


    return meta_dict
end