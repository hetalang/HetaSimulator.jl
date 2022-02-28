using HetaSimulator, Plots, CSV
# heta_update()

### creating platform

p = load_platform(".")  # aproximately the same as "heta build ."
models(p)    # models dictionary
scenarios(p) # scenarios dictionary (empty)

### creating Scenario with Julia code

model = models(p)[:nameless]

# default
scenario0 = Scenario(model, (0, 10); events_active = [:sw1=>false])
res0 = sim(scenario0)
plot(res0)

scenario0 = Scenario(model, (0, 10); events_active = [:sw1=>false])
res0 = sim(scenario0, saveat = [1, 4, 10])
plot(res0)

# update dose
scenario1 = Scenario(
    model,
    parameters = [:dose=>100.],
    events_active = [:sw1=>false, :sw2=>true],
    tspan = (0.,50.),
    observables = [:C1, :C2, :v_abs, :v_el, :v_distr]
)
res1 = sim(scenario1)
plot(res1)

# load scenarios into platform
add_scenarios!(p, [:scn0 => scenario0, :scn1 => scenario1])
p

# simulate all scenarios
res_all = sim(p)
plot(res_all)

### Creating scenarios from tables

scenarios_df = read_scenarios("scenarios.csv")
add_scenarios!(p, scenarios_df)
p

# simulate all scenarios
res_all = sim(p)
plot(res_all)

# simulate selected scenarios
res_all = sim(p, scenarios = [:dose_1, :dose_10, :dose_100])
plot(res_all)

### plot settings

plot(res_all, vars = [:C1, :C2])
plot(res_all, yscale=:log10, ylims=(1e-3,1e2))

### export result into DataFrame

res_df_all = DataFrame(res_all)
CSV.write("res_df_all.csv", res_df_all)

res_df = DataFrame(res_all, vars=[:C1,:C2])
plot(res_df[!,:t], res_df[!,:C1])

### chain syntax

Scenario(models(p)[:nameless], tspan=(0,100)) |> sim |> plot

