# Model name: Story_1
# Number of parameters: 1
# Number of species: 2
using ModelingToolkit: t_nounits as t, D_nounits as D
function get_MTKmodel()

  
  @mtkmodel STORY1 begin

    ### Define dependent variables
    @variables begin 
      s1(t) 
      s2(t)
      _s1(t) 
      _s2(t) 
      r1(t)
    end

    ### Define parameters (constants)
    @parameters begin 
      k1 
      comp1
    end

    @equations begin
      _s1 ~ s1/comp1
      _s2 ~ s2/comp1 # not needed
      r1 ~ k1 * _s1 * comp1
      D(s1) ~ -r1
      D(s2) ~ r1
    end
  end
  @mtkbuild story1 = STORY1()

  ### Initial species concentrations ###
  initialSpeciesValues = [
    story1.s1 => 1.2e+1 
    story1.s2 => 1.2e+1 
  ]

  ### Parameter values ###
  parameterValues = [
    story1.k1 => 0.001,
    story1.comp1 => 1.0
  ]

  return story1, initialSpeciesValues, parameterValues
end

__model__ = get_MTKmodel()