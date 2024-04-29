# Model name: Story_1
# Number of parameters: 6
# Number of species: 4
function get_story1_model()

  ### Define independent and dependent variables
  @variables t 
  dynamicVars = @variables a(t) b(t) c(t) d(t) r1(t) r2(t) a_(t) b_(t) c_(t) d_(t)

  ### Define potential algebraic variables

  ### Define parameters (constants and statics)
  constantParameters = @parameters k1 k2 k3 comp1_cons
  staticParameters = @parameters comp1 comp2

  ### Define an operator for the differentiation w.r.t. time
  D = Differential(t)

  ### ODE Equations ###
  eqs = [
    a ~ a_ / comp1,
    r1 ~ k1 * a,
    b ~ b_ / comp1,
    c ~ c_ / comp1,
    d ~ d_ / comp2,
    r2 ~ k2 * b * c - k3 * d,
    
    D(a_) ~ -r1,  # da_/dt
    D(b_) ~ r1-r2,  # db_/dt
    D(c_) ~ -r2,  # dc_/dt
    D(d_) ~ r2,  # dd_/dt
  ]

  ### Continious events ###

  ### Discrete events ###
  sw1 = [50.0] => [a_ ~ (a_/comp1+1e+0)*comp1]

  ### Parameter values ###
  constantValues = [
    k1 => 0.001,
    k2 => 0.0001,
    k3 => 0.022,
    comp1_cons => 1.0
  ]

  staticValues = [
    comp1 => 1.1 * comp1_cons,
    comp2 => 2.2
  ]

  ### Initial species concentrations ###
  initialSpeciesValues = [
    a_ => 1e+1 * comp1,
    b_ => 0 * comp1,
    c_ => 1e+0 * comp1,
    d_ => 0 * comp2
  ]

  ### ODESystem definition ###
  sys = ODESystem(eqs, t, dynamicVars, [constantParameters; staticParameters],
    name = :story1,
    discrete_events = [sw1],
    defaults = [constantValues; staticValues; initialSpeciesValues]
  )

  return structural_simplify(sys), initialSpeciesValues, constantValues
end

__model__ = get_story1_model()