###
# Methods to transform of heta-compiler generated files into QPlatform content
###

const SUPPORTED_VERSIONS = ["0.6.5", "0.6.6"]

# transformation of tuple to QPlatform
function QPlatform(
    models::NamedTuple,
    conditions::Tuple,
    version::String
)
    # TODO: semver approach might be better
    @assert length(indexin(version, SUPPORTED_VERSIONS)) > 0 "Heta compiler of the version \"$version\" is not supported."

    print("Loading platform... ")
    model_pairs = [pair[1] => QModel(pair[2]...) for pair in pairs(models)]
    
    platform = QPlatform(
        Dict{Symbol,QModel}(model_pairs),
        Dict{Symbol,Cond}()
    )
    println("OK!")

    return platform
end

# transformation of tuple to QModel
function QModel(
    init_func::Function,
    ode_func::Function,
    time_events::NamedTuple,
    c_events::NamedTuple,
    stop_events::NamedTuple,
    saving_generator::Function,
    constants_num::NamedTuple,
    event_active::NamedTuple,
    records_output::NamedTuple
)
    events = AbstractEvent[]
    for event_tuple in time_events # time events
        evt = TimeEvent(event_tuple...)
        push!(events, evt)
    end
    for event_tuple in c_events # c events
        evt = CEvent(event_tuple...)
        push!(events, evt)
    end
    for event_tuple in stop_events # stop events
        evt = StopEvent(event_tuple...)
        push!(events, evt)
    end

    observable_pairs = filter((p) -> p[2], pairs(records_output)) # from records_output
    observables = Symbol[p[1] for p in observable_pairs]
    constants = LVector(constants_num)
    events_on = collect(Pair{Symbol,Bool}, pairs(event_active))

    # Should we (1) store prob in Model, (2) store in Cond (3) nowhere
    ### fake run
    
    _u0, _p0 = init_func(constants)
    _params = Params(constants, _p0)
    prob = ODEProblem(ode_func, _u0, (0.,1.), _params)

    # check if default alg can solve the prob
    integrator = init(prob, DEFAULT_ALG)
    step!(integrator)
    ret = check_error(integrator)
    ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."
    
    model = QModel(
        init_func,          # init_func
        ode_func,           # ode
        events,             # events
        saving_generator,   # saving_generator
        observables,        # observables :: Vector{Symbol}
        constants,          # constants :: LArray
        events_on           # events_on :: Vector{Pair{Symbol,Bool}}
    )

    return model
end
