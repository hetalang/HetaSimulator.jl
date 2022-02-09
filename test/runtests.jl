using HetaSimulator
using Test

function test_show(t)
  try
    display(t)
    return true
  catch e
    return false
  end
end

@testset "HetaSimulator" begin
  @testset "Single-compartment model without events" begin include("single_comp_test.jl") end
end

