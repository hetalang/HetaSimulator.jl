using HetaSimulator, Plots
using DiffEqCallbacks

m = load_mtkmodel("$HetaSimulatorDir/cases/mtk/events/nameless2.jl")
observed(m.sys)
equations(m.sys)
