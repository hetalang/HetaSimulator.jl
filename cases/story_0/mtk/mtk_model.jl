# Model name: Story_1
# Number of parameters: 1
# Number of species: 2
function get_MTKmodel()

  ### Define independent and dependent variables
  @variables t s1(t) s2(t) _s1(t) _s2(t) r1(t)

  ### Define potential algebraic variables

  ### Define parameters (constants and statics)
  @parameters k1 comp1

  ### Define parameter dependencies (statics)
  #@parameters comp1

  ### Store parameter dependencies in array 
  #parameterDepsArray = [
  #  comp1 => 1.0
  #]

  ### Define an operator for the differentiation w.r.t. time
  D = Differential(t)

  ### Continious events ###

  ### Discrete events ###

  ### Derivatives ###
  eqs = [
    _s1 ~ s1/comp1,
    _s2 ~ s2/comp1, # not needed
    r1 ~ k1 * _s1 * comp1,
    D(s1) ~ -r1,
    D(s2) ~ r1
  ]

  @named sys = 
    ODESystem(eqs, t, 
      #stateArray, 
      #parameterArray;
      #parameter_dependencies = parameterDepsArray
    )

  ### Initial species concentrations ###
  initialSpeciesValues = [
    s1 => 1.2e+1 * comp1
    s2 => 1.2e+1 * comp1
  ]

  ### Parameter values ###
  parameterValues = [
    k1 => 0.001,
    comp1 => 1.0
  ]

  return structural_simplify(sys), initialSpeciesValues, parameterValues
end

__model__ = get_MTKmodel()