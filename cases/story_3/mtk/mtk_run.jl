using HetaSimulator, Plots
using DiffEqCallbacks

# set the absolute or relative path to the project directory
m = load_mtkmodel("$HetaSimulatorDir/cases/story_3/mtk/mtk_story3_model.jl")
observed(m.sys)
equations(m.sys)

prob1 = ODEProblem(m.sys, m.u0map, (0.,1000.), [m.sys.Vol1_cons=>1.0])
prob2 = ODEProblem(m.sys, m.u0map, (0.,1000.), [m.sys.Vol1_cons=>2.0])

obs = [:A0, :C1_, :C2_, :Vol1, :Vol2]
# check if obs are present in sys
saved_values = SavedValues(Float64, Vector{Float64})
saved_fun = (u,t,integrator) -> prob2.f.observed(getproperty.((m.sys,), obs))(u, integrator.p, t)
scb = SavingCallback(saved_fun, saved_values)

s = solve(prob2, Tsit5(), callback=scb, save_everystep=false, save_start=false, save_end = false)
saved_values

plot(HetaSimulator.DiffEqArray(saved_values.saveval, saved_values.t), xlims=(0,200))
