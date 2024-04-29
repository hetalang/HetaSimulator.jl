# Model name: Story_3
# Number of parameters: 12
# Number of species: 3
function get_story3_model()

  ### Define independent and dependent variables
  @variables t
  dynamicVars = @variables A0(t) C1(t) C2(t) C1_(t) C2_(t) v_abs(t) v_el(t) v_distr(t)

  ### Define potential algebraic variables

  ### Define parameters (constants and statics)
  constantParameters = @parameters dose kabs kel Q sigma1 sigma2 sigma3 Vol1_cons Vol2_cons
  staticParameters = @parameters Vol0 Vol1 Vol2

  ### Define an operator for the differentiation w.r.t. time
  D = Differential(t)

  ### ODE Equations ###
  eqs = [
    v_abs ~ kabs * A0,
    C1 ~ C1_ / Vol1,
    v_el ~ Vol1 * (kel * C1),
    C2 ~ C2_ / Vol2,
    v_distr ~ Q * (C1 - C2),

    D(A0) ~ -v_abs,  # dA0/dt
    D(C1_) ~ v_abs-v_el-v_distr,  # dC1_/dt
    D(C2_) ~ -v_distr,  # dC2_/dt
  ]

  
  ### Continious events ###

  ### Discrete events ###
  sw1 = [0.0] => [A0 ~ dose]
  sw2 = 24.0 => [A0 ~ dose]

  ### Parameter values ###
  constantValues = [
    dose => 20,
    kabs => 20,
    kel => 0.5,
    Q => 1,
    sigma1 => 0.1,
    sigma2 => 0.1,
    sigma3 => 0.1,
    Vol1_cons => 1.0,
    Vol2_cons => 1.0
  ]

  staticValues = [
    Vol0 => 1e+0,
    Vol1 => 6.3 * Vol1_cons,
    Vol2 => 10.6 * Vol2_cons
  ]

  ### Initial species concentrations ###
  initialSpeciesValues = [
    A0 => 0e+0,
    C1_ => 1e-4 * Vol1,
    C2_ => 1e-4 * Vol2
  ]

  
  sys = ODESystem(eqs, t, dynamicVars, [constantParameters; staticParameters],
    name = :story3,
    discrete_events = [sw1, sw2],
    defaults = [constantValues; staticValues; initialSpeciesValues]
  )
  
  return structural_simplify(sys), initialSpeciesValues, constantValues
end

__model__ = get_story3_model()
