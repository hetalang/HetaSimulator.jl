using ModelingToolkit, Plots

include("story_3/dist/mtk_story_3_IB_v1.jl")

sys = __get_nameless_model__()

prob = ODEProblem(sys, Dict(), (0.0, 100.0))
sol = solve(prob, Tsit5())

sol[:A0]
plot(sol, idxs = [:A0])