using HetaSimulator
using Test

heta_update()

@testset "HetaSimulator" begin
  @testset "Story 1 tests" begin include("story_1_test.jl") end
end
