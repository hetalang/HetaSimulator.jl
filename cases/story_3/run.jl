using HetaSimulator, Plots

p = load_platform("$HetaSimulatorDir/cases/story_3")

# p1 = load_jlplatform("./cases/story_3/dist/julia_platform/model.jl")


### load conditions

cond_df = read_conditions("$HetaSimulatorDir/cases/story_3/conditions.csv")
# cond_df = read_conditions("$HetaSimulatorDir/cases/story_3/conditions.xlsx")
add_conditions!(p, cond_df)

condition1 = conditions(p)[:dose_1]

### create conditions

model = models(p)[:nameless]
new_condition = HetaSimulator.Condition(
    model,
    parameters = [:dose=>100.],
    events_active = [:sw1=>false, :sw1=>true],
    tspan = (0.,1000.),
    observables = [:A0, :C1, :C2, :v_abs, :v_el, :v_distr]
    ) 
push!(conditions(p), :multiple_100=>new_condition)

### create measurements

measurements_df = read_measurements("$HetaSimulatorDir/cases/story_3/measurements.csv")
add_measurements!(p, measurements_df)

### Simulation

res = sim(p)
# plotd = plot(res)
# savefig(plotd, "sim1.png")
# plotd = plot(res[1])
# savefig(plotd, "sim2.png")

res |> plot
res_df = DataFrame(res)

plot(res[1])
res_df1 = DataFrame(res[1])

### Monte-Carlo

mc_res = mc(p, [:kabs=>Normal(10.,1e-1), :kel=>Normal(0.2,1e-3)], 1000)
mc_res |> DataFrame
mc_res |> plot