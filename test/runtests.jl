using HetaSimulator
using Test

@testset "HetaSimulator" begin
  @testset "Heta build" begin include("heta_test.jl") end
  @testset "Single-compartment model without events" begin include("single_comp_test.jl") end
end

