###
# Methods to transform of heta-compiler generated files into Platform content
###

# transformation of tuple to Platform
function Platform(
    models::NamedTuple,
    scenarios::Tuple,
    version::String
)
    # TODO: semver approach might be better
    @assert version in SUPPORTED_VERSIONS "Heta compiler of the version \"$version\" is not supported."

    print("Loading platform... ")
    model_pairs = [pair[1] => Model(pair[2]...) for pair in pairs(models)]
    
    platform = Platform(
        OrderedDict{Symbol,Model}(model_pairs),
        OrderedDict{Symbol,Scenario}()
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
    events_active::NamedTuple,
    records_output::NamedTuple,
    ss_vars::NamedTuple
)
    events = Pair[]
    ## FIXME : remove event name from heta-compiler
    for (name,event_tuple) in pairs(time_events) # time events
        evt = name => TimeEvent(event_tuple[1], event_tuple[2], event_tuple[3])
        push!(events, evt)
    end
    for (name,event_tuple) in pairs(c_events) # c events
        evt = name => CEvent(event_tuple[1], event_tuple[2], event_tuple[3])
        push!(events, evt)
    end
    for (name,event_tuple) in pairs(stop_events) # stop events
        evt = name => StopEvent(event_tuple[1], event_tuple[2])
        push!(events, evt)
    end

    #observable_pairs = filter((p) -> p[2], pairs(records_output)) # from records_output
    #observables = Symbol[p[1] for p in observable_pairs]
    records_output_ = collect(Pair{Symbol,Bool}, pairs(records_output))
    events_active_ = collect(Pair{Symbol,Bool}, pairs(events_active))

    # DAE problems
    ss_ids = values(ss_vars)
    isdae = false in ss_ids
    mass_matrix = isdae ? Diagonal([Bool(s) for s in ss_ids]) : I

    ### fake run, disabled because it slows model loading down
    #=
    _u0, _p0 = init_func(constants_num)
    constants = LVector(constants_num)
    _params = Params(constants, _p0)
    prob = ODEProblem(ode_func, _u0, (0.,1.), _params)

    # check if default alg can solve the prob
    integrator = init(prob, DEFAULT_ALG)
    step!(integrator)
    ret = check_error(integrator)
    ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."
    =#
    model = Model(
        init_func,            # init_func
        ode_func,             # ode_func
        NamedTuple(events),   # events :: Changed to NamedTuple
        saving_generator,     # saving_generator
        records_output_,       
        constants_num,        # constants :: Changed to NamedTuple
        NamedTuple(events_active_), # events_active :: Changed to NamedTuple
        mass_matrix
    )

    return model
end
