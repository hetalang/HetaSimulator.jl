using HetaSimulator, Plots
using DiffEqCallbacks

m = load_mtkmodel("$HetaSimulatorDir/cases/mtk/nameless.jl")
observed(m.sys)
equations(m.sys)

prob = ODEProblem(m.sys, m.u0map, (0.,60.), m.parammap)

obs = [:r4, :_s1_, :comp1]
# check if obs are present in sys
saved_values = SavedValues(Float64, Vector{Float64})
saved_fun = (u,t,integrator) -> prob.f.observed(getproperty.((m.sys,), obs))(u, integrator.p, t)
scb = SavingCallback(saved_fun, saved_values)

s = solve(prob, Tsit5(), callback=scb, save_everystep=false, save_start=false, save_end = false)
saved_values

plot(HetaSimulator.DiffEqArray(saved_values.saveval, saved_values.t))
