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
cond1 = HetaSimulator.Condition(model; parameters = [:k1=>0.02], tspan = (0., 200.), saveat = [0.0, 150., 250.], observables=[:r1])
cond2 = HetaSimulator.Condition(model; parameters = [:k1=>0.015], tspan = (0., 200.), observables=[:r1])
@test typeof(cond1) <: HetaSimulator.Condition
@test saveat(cond1) == [0.0, 150., 250.]
@test saveat(cond2) == Float64[]
@test tspan(cond1) == (0., 250.)
@test tspan(cond2) == (0., 200.)
@test parameters(cond1)[:k1] == 0.02
@test parameters(cond2)[:k1] == 0.015

cs1 = sim(cond1)
cs2 = sim([:one=>cond1,:two=>cond2])
@test typeof(cs1) <: HetaSimulator.SimResults
@test typeof(cs2) <: Vector{Pair{Symbol, HetaSimulator.SimResults}}


# Monte-Carlo simulation tests
mc1 =  mc(model, [:k1=>Normal(0.02,1e-3)], 100; tspan = (0., 200.), observables=[:r1])
mc2 = mc([:one=>cond1,:two=>cond2], [:k1=>Normal(0.02,1e-3)], 100)
@test typeof(mc1) <: HetaSimulator.MCResults
@test typeof(mc2) <: Vector{Pair{Symbol, HetaSimulator.MCResults}}
@test typeof(mc1[1]) <: HetaSimulator.Simulation
@test typeof(mc2[1]) <: Pair{Symbol, HetaSimulator.MCResults}
@test length(mc1) == 100
@test times(mc1[1])[end] == 200.

# Fitting tests
fcond1 = HetaSimulator.Condition(model; parameters = [:k1=>0.02], tspan = (0., 200.), observables=[:A, :B, :r1])
fcond2 = HetaSimulator.Condition(model; parameters = [:k1=>0.015], tspan = (0., 200.), observables=[:A, :B, :r1])
data = read_measurements("$HetaSimulatorDir/test/examples/single_comp/single_comp_data.csv")
add_measurements!(fcond1, data; subset = [:condition => :one])
add_measurements!(fcond2, data; subset = [:condition => :two])
fres = fit([:one=>fcond1, :two=>fcond2], [:k1=>0.01])

@test length(measurements(fcond1)) == 24
@test length(measurements(fcond2)) == 24
@test status(fres) == :FTOL_REACHED
@test obj(fres) ≈ 146.056244
@test typeof(optim(fres)) == Vector{Pair{Symbol, Float64}}
@test length(optim(fres)) == 1