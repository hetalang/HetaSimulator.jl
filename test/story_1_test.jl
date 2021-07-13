platform = load_platform("$HetaSimulatorDir/cases/story_1", rm_out = false);
model = platform.models[:nameless];

cond = Condition(model; tspan = (0., 200.), saveat = [0.0, 150., 250.])
s = sim(cond)
mcs = mc(cond, [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 1000)

@test typeof(cond) <: HetaSimulator.Condition
@test typeof(s) <: HetaSimulator.SimResults
@test typeof(mcs) <: HetaSimulator.MCResults