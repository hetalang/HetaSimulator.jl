###
# Methods to transform of heta-compiler generated files into QPlatform content
###

# transformation of tuple to QPlatform
function QPlatform(platform_tuple::Tuple{NamedTuple,Tuple,String})
    print("Loading platform... ")
    model_pairs = [pair[1] => QModel(pair[2]) for pair in pairs(platform_tuple[1])]
    
    platform = QPlatform(Dict{Symbol,QModel}(model_pairs), Dict{Symbol,Cond}())
    println("OK!")

    return platform
end

# transformation of tuple to QModel
function QModel(model_tuple::Tuple{Function, Function, NamedTuple, NamedTuple, Function, NamedTuple, NamedTuple, NamedTuple})
    events = AbstractEvent[]
    for event_tuple in model_tuple[3] # time events
        evt = TimeEvent(event_tuple...)
        push!(events, evt)
    end
    for event_tuple in model_tuple[4] # c events
        evt = CEvent(event_tuple...)
        push!(events, evt)
    end

    init_func = model_tuple[1]
    observable_pairs = filter((p) -> p[2], pairs(model_tuple[8])) # from records_output
    observables = Symbol[p[1] for p in observable_pairs]
    constants = LVector(model_tuple[6])
    events_on = collect(Pair{Symbol,Bool}, pairs(model_tuple[7]))

    # Should we (1) store prob in Model, (2) store in Cond (3) nowhere
    ### fake run
    
    _u0, _p0 = init_func(constants)
    _params = Params(constants, _p0)
    prob = ODEProblem(model_tuple[2], _u0, (0.,1.), _params)

    # check if default alg can solve the prob
    integrator = init(prob, DEFAULT_ALG)
    step!(integrator)
    ret = check_error(integrator)
    ret != :Success && @warn "Default algorithm returned $ret status. Consider using a different algorithm."
    
    model = QModel(
        init_func,            # init_func
        model_tuple[2],       # ode
        events,               # events
        model_tuple[5],       # saving_generator
        observables,          # observables :: Vector{Symbol}
        constants,            # constants :: LArray
        events_on             # events_on :: Vector{Pair{Symbol,Bool}}
    )

    return model
end
