platform = load_platform("$HetaSimulatorDir/test/examples/single_comp", rm_out = false);
model = platform.models[:nameless];

@test isfile("$HetaSimulatorDir/test/examples/single_comp/_julia/model.jl")

# Wrong input tests
## no saveat or tspan
@test_throws ErrorException("Please, provide either `saveat` or `tspan` value.") HetaSimulator.Condition(model)
## wrong observables
@test_throws ErrorException("The following observables have not been found in the model: [:GG]") HetaSimulator.Condition(model; observables=[:r1, :GG], tspan=(0,120))

# Simulate model
s = sim(model, tspan = (0., 200.), saveat = [0.0, 150., 250.], observables=[:r1])
@test typeof(s) <: HetaSimulator.SimResults
@test status(s) == :Success
@test times(s)[end] == 250.
@test vals(s)[1][:r1] == 0.1

# Simulate condition
cond = HetaSimulator.Condition(model; parameters = [:k1=>0.02], tspan = (0., 200.), saveat = [0.0, 150., 250.])
@test typeof(cond) <: HetaSimulator.Condition
@test saveat(cond) == [0.0, 150., 250.]
@test tspan(cond) == (0., 250.)
@test parameters(cond)[:k1] == 0.02

cs = sim(cond)
@test typeof(s) <: HetaSimulator.SimResults
