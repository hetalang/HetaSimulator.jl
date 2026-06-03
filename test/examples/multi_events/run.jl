using HetaSimulator
using Plots, DataFrames

p = load_jlplatform("model.jl")
m = models(p)[:nameless]

# threeshold: 2.5 - wrong, 1.5 - wrong, 0.5 - wrong
scn = Scenario(m, (0., 1200.); parameters = [:threeshold => 1.0])
res1 = sim(scn)
plot(res1; vars = [:s3, :s4])
plot(res1; vars = [:s5, :s6])
