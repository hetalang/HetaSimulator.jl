last_saved(result, t, id) = result[id, findlast(==(t), times(result))]

p = load_platform("$HetaSimulatorDir/test/examples/multi_events")
m = models(p)[:nameless]


scn1 = Scenario(m, (0., 1200.); parameters = [:threeshold => 0.5])
res1 = sim(scn1)
df1 = DataFrame(res1)
t_sw3 = df1.t[findfirst(>(0.9), diff(df1.s3)) + 1]

@test last_saved(res1, 0., :s1) == 2.0
@test last_saved(res1, t_sw3, :s3) ≈ 1.5
@test res1(t_sw3, :s3) ≈ 0.5

# HetaImporter 0.3.1 uses separate ContinuousCallbacks. SciML currently drops
# the second root when sw3 and sw4 cross simultaneously. Record the upstream
# limitation explicitly, and verify that the adapter matches a native solve.
native = solve(ODEProblem(m, (0., 1200.); p=[:threeshold=>0.5]),
    HetaSimulator.DEFAULT_ALG; reltol=1e-3, abstol=1e-6)
@test maximum(diff(res1[:s4,:])) == maximum(diff(native[:s4]))
@test_broken maximum(diff(res1[:s4,:])) ≈ 1.0

only_sw4 = sim(Scenario(m, (0., 1200.); parameters=[:threeshold=>0.5],
    events_active=[:sw3=>false]))
t_sw4 = times(only_sw4)[findfirst(>(0.9), diff(only_sw4[:s4,:])) + 1]
@test last_saved(only_sw4, t_sw4, :s4) ≈ 1.5

scn2 = Scenario(m, (0., 1200.); parameters = [:threeshold => 1.5])
res2 = sim(scn2)
df2 = DataFrame(res2)
t_sw3 = unique(vcat(0., df2.t[findall(>(0.9), diff(df2.s3)) .+ 1]))

@test [last_saved(res2, t, :s3) for t in t_sw3] ≈ [2.0, 2.5, 2.5]
@test last_saved(res2, 0., :s1) == 2.0
@test last_saved(res2, 0., :s5) == 2.0

scn3 = Scenario(m, (0., 1200.); parameters = [:threeshold => 2.5])
res3 = sim(scn3)

@test last_saved(res3, 0., :s1) == 2.0
@test last_saved(res3, 0., :s3) == 2.0
@test last_saved(res3, 0., :s5) == 2.0

# Independent native callbacks and parameter buffers for repeated and ensemble runs.
@test DataFrame(sim(scn1)) == df1
ensemble = sim([scn1, scn2]; parallel_type=EnsembleThreads())
@test vals(last(ensemble[1])) == vals(res1)
@test vals(last(ensemble[2])) == vals(res2)
@test !hasproperty(res1.sim, :scope)
@test "scope" ∉ names(DataFrame(res1))
