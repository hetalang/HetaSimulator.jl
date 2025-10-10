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

    __algebraics__ = @variables begin
        _z_(t)  
    end

    __rules__ = @variables begin 
        x1(t) 
        x2(t)
        r1(t) 
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

        # ODEs
        __D__(_x1_) ~ -r1, # dx1/dt
        __D__(_x2_) ~ r1, # dx2/dt
         0 ~ (_z_)^2 - (_x1_)^2 + 0.5(_x2_)^2 # algebraic equation

    ]

    ### TIME EVENTS ###

    ### STOP EVENTS ###

    ### ODESystem definition ###
    __sys__ = System(__eqs__, t, [__states__; __algebraics__; __rules__], [__const_parameters__; __dependent_parameters__; __discrete_parameters__],;
        name = :nameless, guesses = Dict(_z_ => 0.0)
    )

    return structural_simplify(__sys__)
end

__model__ = __get_mtk_model__()

prob = ODEProblem(__model__, Dict(), (0.0, 100.0))
sol = solve(prob, Rodas5P(), saveat=1.0)
