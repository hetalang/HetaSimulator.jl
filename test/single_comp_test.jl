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
add_scenarios!(platform, read_scenarios("$HetaSimulatorDir/test/examples/single_comp/scenarios_table.csv"))

@test typeof(scn1) <: Scenario
@test test_show(scn1)
@test tspan(scn1) == (0., 200.)
@test tspan(scn2) == (0., 150.)
@test parameters(scn1)[:k1] == 0.02
@test parameters(scn2)[:k1] == 0.015

cs1 = sim(scn1)
cs2 = sim([:one=>scn1,:two=>scn2], parameters=[:k1=>0.03])
cs3 = sim(scenarios(platform)[:scn3])
@test typeof(cs1) <: HetaSimulator.SimResult
@test typeof(cs2) <: Vector{Pair{Symbol, HetaSimulator.SimResult}}
@test length(parameters(cs1))==0
@test parameters(last(cs2[:one]))[:k1] == 0.03
@test parameters(scenarios(platform)[:scn3])[:k1] == 0.017
# tests both saveat times and sanitize whitespaces in colnames
@test times(cs3) == [12.,17.,30.,40.,50.,60.,80.,100.,120.] 

# Monte-Carlo simulation tests
mciter = 100

mc1 = mc(Scenario(model, (0., 200.), observables=[:r1], saveat=0:10:200), [:k1=>Normal(0.02,1e-3)], mciter)
mc2 = mc([:one=>scn1,:two=>scn2], [:k1=>Normal(0.02,1e-3)], mciter)
ens = EnsembleSummary(mc1)
@test typeof(ens) <: HetaSimulator.LabelledEnsembleSummary
@test typeof(mc1) <: HetaSimulator.MCResult
@test test_show(mc1)
@test typeof(mc2) <: Vector{Pair{Symbol, HetaSimulator.MCResult}}
@test typeof(mc1[1]) <: HetaSimulator.Simulation
@test typeof(mc2[1]) <: Pair{Symbol, HetaSimulator.MCResult}
@test length(mc1) == mciter
@test typeof(parameters(mc1)) <: Vector
@test times(mc1[1])[end] == 200.
@test keys((parameters(mc1[1]))) == (:k1,)

#=
function reduction_func(mcsol, sol, I)
  (last.(vals.(sol)), false)
end
=#

mcvecs = [:k1 => [0.020783602070669163, 0.01847900966763524, 0.019406029840389655, 0.0200093097396787, 0.02124418652960589, 0.020423641771795314, 0.02005492267203665, 0.020021743479121643, 0.022069617799266517, 0.019389545481448302]]

function reduction_func1(u, batch, i)
  for s in batch
    t1 = 200.
    var = :r1
    if s(t1, var) > 0.004
      push!(u, s)
    end
  end
  (u,false)
end

sc1 = Scenario(model, (0., 200.), observables=[:r1])
mc1_reduced = mc(sc1, mcvecs, 10; reduction_func=reduction_func1)

@test length(mc1_reduced) == 3


# Fitting tests
fscn1 = Scenario(model, (0., 200.); parameters = [:k1=>0.02], observables=[:A, :B, :r1])
fscn2 = Scenario(model, (0., 200.); parameters = [:k1=>0.015], observables=[:A, :B, :r1])
data = read_measurements("$HetaSimulatorDir/test/examples/single_comp/single_comp_data.csv")
add_measurements!(fscn1, data; subset = [:scenario => :one])
add_measurements!(fscn2, data; subset = [:scenario => :two])
fres = fit([:one=>fscn1, :two=>fscn2], [:k1=>0.01, :sigma1=>1.0], progress=:silent)

@test typeof(fres) <: HetaSimulator.FitResult
@test test_show(fres)
@test length(measurements(fscn1)) == 24
@test length(measurements(fscn2)) == 24
@test status(fres) == :Success
@test isapprox(obj(fres), 146.05; atol=1e-2)
@test typeof(optim(fres)) == Vector{Pair{Symbol, Float64}}
@test length(optim(fres)) == 2