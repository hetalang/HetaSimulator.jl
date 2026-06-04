p = load_jlplatform("$HetaSimulatorDir/test/examples/multi_events/model.jl")
m = models(p)[:nameless]


scn1 = Scenario(m, (0., 1200.); parameters = [:threeshold => 0.5])
res1 = sim(scn1)
df1 = DataFrame(res1)
t_sw3 = filter(:scope => x -> x == :sw3, df1).t[1]
t_sw4 = filter(:scope => x -> x == :sw4, df1).t[1]

@test res1(0., :s1, :sw1) == 2.0
@test res1(t_sw3, :s3, :sw3) == 1.5
@test res1(t_sw3, :s4, :sw3) == 0.5
@test res1(t_sw4, :s4, :sw4) == 1.5

scn2 = Scenario(m, (0., 1200.); parameters = [:threeshold => 1.5])
res2 = sim(scn2)
df2 = DataFrame(res2)
t_sw3 = filter(:scope => x -> x == :sw3, df2).t

@test res2.(t_sw3, :s3, :sw3) == [2.0, 2.5, 2.5]
@test res2(0., :s1, :sw1) == 2.0
@test res2(0., :s5, :sw5) == 2.0

scn3 = Scenario(m, (0., 1200.); parameters = [:threeshold => 2.5])
res3 = sim(scn3)

@test res3(0., :s1, :sw1) == 2.0
@test res3(0., :s3, :sw3) == 2.0
@test res3(0., :s5, :sw5) == 2.0
