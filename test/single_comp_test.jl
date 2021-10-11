platform = load_platform("$HetaSimulatorDir/test/examples/single_comp", rm_out = false);
model = platform.models[:nameless];

@test isfile("$HetaSimulatorDir/test/examples/single_comp/_julia/model.jl")

# Wrong input tests
## no saveat or tspan
@test_throws ErrorException("Please, provide either `saveat` or `tspan` value.") Scenario(model)
## wrong observables
@test_throws ErrorException("The following observables have not been found in the model: [:GG]") Scenario(model; observables=[:r1, :GG], tspan=(0,120))

# Simulate default scenario
s = Scenario(model, tspan = (0., 200.), saveat = [0.0, 150., 250.], observables=[:r1]) |> sim
@test typeof(s) <: HetaSimulator.SimResults
@test status(s) == :Success
@test times(s)[end] == 250.
@test vals(s)[1][:r1] == 0.1

# tests related to saveat, tspan behavior
s1 = Scenario(model, tspan = (0., 200.)) |> sim
s2 = Scenario(model, saveat = [150., 200.]) |> sim
@test_broken times(s1)[1] == 0.0
@test times(s1)[end] == 200.0
@test times(s2) == [150., 200.]

# Simulate scenario
scn1 = Scenario(model; parameters = [:k1=>0.02], tspan = (0., 200.), saveat = [0.0, 150., 250.], observables=[:r1])
scn2 = Scenario(model; parameters = [:k1=>0.015], tspan = (0., 200.), observables=[:r1])
@test typeof(scn1) <: Scenario
@test saveat(scn1) == [0.0, 150., 250.]
@test saveat(scn2) == Float64[]
@test tspan(scn1) == (0., 250.)
@test tspan(scn2) == (0., 200.)
@test parameters(scn1)[:k1] == 0.02
@test parameters(scn2)[:k1] == 0.015

cs1 = sim(scn1)
cs2 = sim([:one=>scn1,:two=>scn2], parameters_upd=[:k1=>0.03])
@test typeof(cs1) <: HetaSimulator.SimResults
@test typeof(cs2) <: Vector{Pair{Symbol, HetaSimulator.SimResults}}
@test isnothing(parameters(cs1))
@test parameters(last(cs2[:one]))[:k1] == 0.03

# Monte-Carlo simulation tests
mc1 =  mc(model, [:k1=>Normal(0.02,1e-3)], 100; tspan = (0., 200.), observables=[:r1])
mc2 = mc([:one=>scn1,:two=>scn2], [:k1=>Normal(0.02,1e-3)], 100)
@test typeof(mc1) <: HetaSimulator.MCResults
@test typeof(mc2) <: Vector{Pair{Symbol, HetaSimulator.MCResults}}
@test typeof(mc1[1]) <: HetaSimulator.Simulation
@test typeof(mc2[1]) <: Pair{Symbol, HetaSimulator.MCResults}
@test length(mc1) == 100
@test times(mc1[1])[end] == 200.
@test keys((parameters(mc1[1]))) == (:k1,)

# Fitting tests
fscn1 = Scenario(model; parameters = [:k1=>0.02], tspan = (0., 200.), observables=[:A, :B, :r1])
fscn2 = Scenario(model; parameters = [:k1=>0.015], tspan = (0., 200.), observables=[:A, :B, :r1])
data = read_measurements("$HetaSimulatorDir/test/examples/single_comp/single_comp_data.csv")
add_measurements!(fscn1, data; subset = [:scenario => :one])
add_measurements!(fscn2, data; subset = [:scenario => :two])
fres = fit([:one=>fscn1, :two=>fscn2], [:k1=>0.01])

@test length(measurements(fscn1)) == 24
@test length(measurements(fscn2)) == 24
@test status(fres) == :FTOL_REACHED
@test obj(fres) ≈ 146.056244
@test typeof(optim(fres)) == Vector{Pair{Symbol, Float64}}
@test length(optim(fres)) == 1