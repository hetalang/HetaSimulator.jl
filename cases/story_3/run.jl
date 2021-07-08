using HetaSimulator, Plots

p = load_platform("./cases/story_3")

# p1 = load_jlplatform("./cases/story_3/dist/julia_platform/model.jl")


### load conditions

cond_df = read_conditions("./cases/story_3/conditions.csv")
add_conditions!(p, cond_df)

p

condition1 = conditions(p)[:dose_1]

cond_df = read_conditions("./cases/story_3/conditions.xlsx")

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

measurements_df = read_measurements("./cases/story_3/measurements.csv")
add_measurements!(p, measurements_df)
