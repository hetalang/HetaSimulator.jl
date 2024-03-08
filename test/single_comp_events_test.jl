platform = load_platform("$HetaSimulatorDir/test/examples/single_comp_events");
model = platform.models[:nameless];

scn0 = Scenario(model, (0.,4000.); observables=[:a0,:c1])
s0 = sim(scn0; tstops=[100., 100.1])
@test isapprox(s0(100.1)[:a0]-s0(100.)[:a0], 0.0; atol=1e-2)
@test isapprox(s0(100.1)[:c1]-s0(100.)[:c1], 0.0; atol=1e-2)

scn1 = Scenario(model, (0.,4000.); observables=[:a0,:c1], events_active=[:sw=>true, :sw_end=>true], events_save=(true,true))
s1 = sim(scn1)
@test isapprox(s1(100.1)[:a0]-s1(100.)[:a0], 1.0; atol=1e-2)
@test isapprox(s1(100.1)[:c1]-s1(100.)[:c1], 0.0; atol=1e-2)