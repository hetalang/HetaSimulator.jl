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

mc_res = mc(p, [:kabs=>Normal(10.,5e-1), :kel=>Normal(0.2,5e-3)], 1000)
mc_res |> DataFrame
mc_res |> plot
# plotd = plot(mc_res)
# savefig(plotd, "sim3.png")

# DataFrame(mc_res[:dose_1])
# plot(mc_res[:dose_1])

### Fitting

res0 = sim(p)
plot(res0, yscale=:log, ylims=(1e-3,1e2))
# plotd = plot(res0, yscale=:log, ylims=(1e-3,1e2))
# savefig(plotd, "sim4.png")

to_fit = [
    :kabs => 8.0,
    :Q => 4.0,
    :kel => 2.2,
    :sigma1 => 0.1,
    :sigma2 => 0.1,
    :sigma3 => 0.1,
]
fit_res = fit(p, to_fit)

optim(fit_res)

res_optim = sim(p, parameters_upd = optim(fit_res))
plot(res_optim, yscale=:log, ylims=(1e-3,1e2))
# plotd = plot(res_optim, yscale=:log, ylims=(1e-3,1e2))
# savefig(plotd, "sim5.png")

### to check
res_x = sim(p, parameters_upd = [:kabs => 20.0, :Q => 1.0, :kel => 5.0e-01])
plot(res_x, yscale=:log, ylims=(1e-3,1e2))

### fitting with parameters.csv table

# all parameters are estimated (the same as fit_res)
params_df0 = read_parameters("$HetaSimulatorDir/cases/story_3/parameters0.csv")
fit_res0 = fit(p, params_df0)

# overwrite dose and estimate other parameters
params_df1 = read_parameters("$HetaSimulatorDir/cases/story_3/parameters.csv")
fit_res1 = fit(p, params_df)