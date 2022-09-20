platform = load_platform("$HetaSimulatorDir/test/examples/single_comp", rm_out = false);
model = platform.models[:nameless];
@test test_show(platform)
@test test_show(model)

@test isfile("$HetaSimulatorDir/test/examples/single_comp/_julia/model.jl")

# Wrong input tests
## no saveat or tspan
#@test_throws ErrorException("Please, provide either `saveat` or `tspan` value.") Scenario(model)
## wrong observables
@test_throws ErrorException("The following observables have not been found in the model: [:GG]") Scenario(model, (0,120); observables=[:r1, :GG])

# Simulate default scenario
s = sim(Scenario(model, (0., 200.), observables=[:r1], saveat = [0.0, 150., 250.]))
@test test_show(s)
@test typeof(s) <: HetaSimulator.SimResult
@test status(s) == :Success
@test times(s)[end] == 150.
@test vals(s)[1][:r1] == 0.1

# tests related to saveat, tspan behavior
s1 = Scenario(model, (0., 200.)) |> sim
s2 = sim(Scenario(model, (0,250); saveat = [150., 200.]))
@test times(s1)[1] == 0.0
@test times(s1)[end] == 200.0
@test times(s2) == [150., 200.]

# Simulate scenario
scn1 = Scenario(model, (0., 200.); parameters = [:k1=>0.02], observables=[:r1])
scn2 = Scenario(model, (0., 150.); parameters = [:k1=>0.015], observables=[:r1])
@test typeof(scn1) <: Scenario
@test test_show(scn1)
@test tspan(scn1) == (0., 200.)
@test tspan(scn2) == (0., 150.)
@test parameters(scn1)[:k1] == 0.02
@test parameters(scn2)[:k1] == 0.015

cs1 = sim(scn1)
cs2 = sim([:one=>scn1,:two=>scn2], parameters=[:k1=>0.03])
@test typeof(cs1) <: HetaSimulator.SimResult
@test typeof(cs2) <: Vector{Pair{Symbol, HetaSimulator.SimResult}}
@test length(parameters(cs1))==0
@test parameters(last(cs2[:one]))[:k1] == 0.03

# Monte-Carlo simulation tests
mciter = 100

function output_func(sol, i)
  last(vals(sol))
end

#=
function reduction_func(mcsol, sol, I)
  (last.(vals.(sol)), false)
end
=#

mc1 = mc(Scenario(model, (0., 200.), observables=[:r1]), [:k1=>Normal(0.02,1e-3)], mciter)
mc2 = mc([:one=>scn1,:two=>scn2], [:k1=>Normal(0.02,1e-3)], mciter)
mc1_reduced = mc(Scenario(model, (0., 200.), observables=[:r1]), [:k1=>Normal(0.02,1e-3)], mciter; output_func=output_func)
gsar = gsa(mc1, 200)
@test typeof(mc1) <: HetaSimulator.MCResult
@test test_show(mc1)
@test typeof(mc2) <: Vector{Pair{Symbol, HetaSimulator.MCResult}}
@test typeof(mc1[1]) <: HetaSimulator.Simulation
@test typeof(mc2[1]) <: Pair{Symbol, HetaSimulator.MCResult}
@test length(mc1) == mciter
@test typeof(parameters(mc1)) <: Vector
@test times(mc1[1])[end] == 200.
@test keys((parameters(mc1[1]))) == (:k1,)
@test size(pearson(gsar)) == (1,1)
@test size(partial(gsar)) == (1,1)
@test size(standard(gsar)) == (1,1)
@test length(mc1_reduced) == mciter


# Fitting tests
fscn1 = Scenario(model, (0., 200.); parameters = [:k1=>0.02], observables=[:A, :B, :r1])
fscn2 = Scenario(model, (0., 200.); parameters = [:k1=>0.015], observables=[:A, :B, :r1])
data = read_measurements("$HetaSimulatorDir/test/examples/single_comp/single_comp_data.csv")
add_measurements!(fscn1, data; subset = [:scenario => :one])
add_measurements!(fscn2, data; subset = [:scenario => :two])
fres = fit([:one=>fscn1, :two=>fscn2], [:k1=>0.01], progress=:silent)

@test typeof(fres) <: HetaSimulator.FitResult
@test test_show(fres)
@test length(measurements(fscn1)) == 24
@test length(measurements(fscn2)) == 24
@test status(fres) == :FTOL_REACHED
@test obj(fres) ≈ 146.056244
@test typeof(optim(fres)) == Vector{Pair{Symbol, Float64}}
@test length(optim(fres)) == 1