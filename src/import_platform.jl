###
# Methods to transform of heta-compiler generated files into Platform content
###

const SUPPORTED_VERSIONS = ["0.6.5", "0.6.6"]

# transformation of tuple to Platform
function Platform(
    models::NamedTuple,
    conditions::Tuple,
    version::String
)
    # TODO: semver approach might be better
    @assert length(indexin(version, SUPPORTED_VERSIONS)) > 0 "Heta compiler of the version \"$version\" is not supported."

    print("Loading platform... ")
    model_pairs = [pair[1] => Model(pair[2]...) for pair in pairs(models)]
    
    platform = Platform(
        Dict{Symbol,Model}(model_pairs),
        Dict{Symbol,Cond}()
    )
    println("OK!")

    return platform
end

# transformation of tuple to Model
function Model(
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
    events = Pair[]
    ## FIXME : remove event name from heta-compiler
    for (name,event_tuple) in pairs(time_events) # time events
        evt = name => TimeEvent(event_tuple[1], event_tuple[2], event_tuple[4])
        push!(events, evt)
    end
    for (name,event_tuple) in pairs(c_events) # c events
        evt = name => CEvent(event_tuple[1], event_tuple[2], event_tuple[4])
        push!(events, evt)
    end
    for (name,event_tuple) in pairs(stop_events) # stop events
        evt = name => StopEvent(event_tuple[1], event_tuple[3])
        push!(events, evt)
    end

    observable_pairs = filter((p) -> p[2], pairs(records_output)) # from records_output
    observables = Symbol[p[1] for p in observable_pairs]
    events_active = collect(Pair{Symbol,Bool}, pairs(event_active))

    # Should we (1) store prob in Model, (2) store in Cond (3) nowhere
    ### fake run
    
    _u0, _p0 = init_func(constants_num)
    constants = LVector(constants_num)
    _params = Params(constants, _p0)
    prob = ODEProblem(ode_func, _u0, (0.,1.), _params)

    # check if default alg can solve the prob
    integrator = init(prob, DEFAULT_ALG)
    step!(integrator)
    ret = check_error(integrator)
    ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."
    
    model = Model(
        init_func,            # init_func
        ode_func,             # ode_func
        NamedTuple(events),   # events :: Changed to NamedTuple
        saving_generator,     # saving_generator
        observables,          # observables :: Vector{Symbol}
        constants_num,        # constants :: Changed to NamedTuple
        NamedTuple(events_active) # events_active :: Changed to NamedTuple
    )

    return model
end
