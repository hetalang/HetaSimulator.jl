using ModelingToolkit, OrdinaryDiffEq, Plots


function __get_mtk_model__()

    ### Define independent variables ###
    @independent_variables t

    ### Define parameters (constants and statics) ###
    __const_parameters__ = @parameters begin 
        k1_factor = 1.0
        comp1_factor = 1.0
    end

    __discrete_parameters__ = @parameters begin 
        p1(t) = 1.0
        p2(t) = p1
    end

    __dependent_parameters__ = @parameters begin 
        k1 = 1e-2 * k1_factor
        comp1 = 1.0 * comp1_factor
    end

    ### Define dependent variables ###

    __states__ = @variables begin
        _x1_(t)  = 1.0 * comp1
        _x2_(t)  = 0.0 * comp1
    end

    __rules__ = @variables begin 
        x1(t) 
        x2(t) 
        r1(t) 
        cond1(t)
        p1_dep_var(t)
    end

    ### Define potential algebraic variables ###


    ### Define an operator for the differentiation w.r.t. time ###
    __D__ = Differential(t)

    ### ODE Equations ###
    __eqs__ = [
        # rules
        x1 ~ _x1_/ comp1,
        x2 ~ _x2_/ comp1,
        r1 ~ k1 * x1 * comp1,
        cond1 ~ 6e-1 - x1,
        p1_dep_var ~ p1 + 100.0,

        # ODEs
        __D__(_x1_) ~ -r1, # dx1/dt
        __D__(_x2_) ~ r1, # dx2/dt
    ]

    ### TIME EVENTS ###

    ### C EVENTS ###
    __sw1_event__ = ModelingToolkit.SymbolicContinuousCallback([cond1 ~ 0.0] => [p1 ~ 2*Pre(p1)], discrete_parameters = [p1, p2], iv = t)

    ### STOP EVENTS ###

    ### ODESystem definition ###
    __sys__ = ODESystem(__eqs__, t, [__states__; __rules__], [__const_parameters__; __dependent_parameters__; __discrete_parameters__],;
        name = :nameless,
        continuous_events = [__sw1_event__]
    )

    return structural_simplify(__sys__)
end

__model__ = __get_mtk_model__()

prob = ODEProblem(__model__, Dict(), (0.0, 100.0))
sol = solve(prob, Tsit5(), saveat=1.0, save_discretes=true)

# states
sol[:_x1_]
sol[:_x2_]

# rules
sol[:x1]
sol[:x2]
sol[:r1]
sol[:cond1]

# parameters
sol.ps[:k1]

# discrete parameters
sol[__model__.p1]
sol([3.0, 12.003, 52.95], idxs=[__model__.p1, :r1, :p1_dep_var])
