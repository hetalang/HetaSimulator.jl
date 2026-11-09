#=
  default run
=#
using HetaSimulator, Plots

model = models(load_platform(dirname(@__DIR__)))[:nameless]

### default simulations

Scenario(model, (0, 100)) |> sim |> plot
