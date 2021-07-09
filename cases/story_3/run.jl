using HetaSimulator, Plots

p = load_platform("$HetaSimulatorDir/cases/story_3")

# p1 = load_jlplatform("./cases/story_3/dist/julia_platform/model.jl")


### load conditions

cond_df = read_conditions("$HetaSimulatorDir/cases/story_3/conditions.csv")
add_conditions!(p, cond_df)


condition1 = conditions(p)[:dose_1]

cond_df = read_conditions("$HetaSimulatorDir/cases/story_3/conditions.xlsx")

### create conditions

model = models(p)[:nameless]
new_condition = Cond(
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
res |> plot
