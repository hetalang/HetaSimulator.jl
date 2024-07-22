using HetaSimulator, Plots
using DiffEqCallbacks

m = load_mtkmodel("$HetaSimulatorDir/cases/mtk/nameless.jl")
observed(m.sys)
equations(m.sys)

prob1 = ODEProblem(m.sys, nothing, (0.,60.), [m.sys.s11_0=>1.0])
prob2 = ODEProblem(m.sys, nothing, (0.,60.), [m.sys.s11_0=>10.0])

obs = [:_s11_, :s11]

function solve_prob(prob, obs)
  # check if obs are present in sys
  saved_values = SavedValues(Float64, Vector{Float64})
  saved_fun = (u,t,integrator) -> prob.f.observed(getproperty.((m.sys,), obs))(u, integrator.p, t)
  scb = SavingCallback(saved_fun, saved_values)

  s = solve(prob, Tsit5(), callback=scb, save_everystep=false, save_start=false, save_end = false)
  saved_values
end

sv1 = solve_prob(prob1, obs)
plot(HetaSimulator.DiffEqArray(sv1.saveval, sv1.t))

sv2 = solve_prob(prob2, obs)
plot(HetaSimulator.DiffEqArray(sv2.saveval, sv2.t))
