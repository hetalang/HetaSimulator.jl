# the code was tested on v0.4.2
# reinstall HetaSimulator
# ] add https://github.com/hetalang/HetaSimulator.jl

using HetaSimulator, Plots

p = load_platform(".")

# load scenarios
scn_df = read_scenarios("./scenarios.csv")
add_scenarios!(p, scn_df)

### Load measurements

# see table measurements.csv describing data with unknown variance
# see more detales in https://hetalang.github.io/HetaSimulator.jl/dev/table-formats/measurement/
measurements_df = read_measurements("./measurements.csv")
add_measurements!(p, measurements_df)

# display platform content
p

### simulate all
res = sim(p)

# plot all default
plot(res)
# plotd = plot(res)
# savefig(plotd, "fig.png")

# plot C1, C2 in log scale
plot(res, vars=[:C1,:C2], yscale=:log10, ylim=(1e-3, 1e3))
# plotd = plot(res, vars=[:C1,:C2], yscale=:log10, ylim=(1e-3, 1e3))
# savefig(plotd, "fig.png")

### Fitting

# fitted parameters
to_fit = [
    :kabs => 8.0,
    :Q => 4.0,
    :kel => 2.2,
    :sigma1 => 0.1,
    :sigma2 => 0.1,
    :sigma3 => 0.1,
]
res_optim = fit(p, to_fit) # default fitting

# optimal parameters
optim(res_optim)

# check fitting quality 
res = sim(p, parameters_upd = optim(res_optim))
plot(res, yscale=:log10, ylims=(1e-3,1e2))
# plotd = plot(res_optim, vars=[:C1,:C2], yscale=:log10, ylims=(1e-3,1e2))
# savefig(plotd, "fig.png")

### Fitting with parameters table

# read parameters from table
params_df = read_parameters("./parameters.csv")
res_optim = fit(p, params_df)

### additional optimization-specific options

# see also https://nlopt.readthedocs.io/en/latest/NLopt_Algorithms/
res_optim = fit(
    p, 
    params_df, 
    fit_alg = :LN_SBPLX, 
    ftol_abs = 1e-5, 
    ftol_rel = 0, 
    maxeval = 10^6
)
optim(res_optim)

#= see API docs
fit_alg : fitting algorithm. Default is :LN_NELDERMEAD
ftol_abs : absolute tolerance on function value. Default is 0.0
ftol_rel : relative tolerance on function value. Default is 1e-4
xtol_rel : relative tolerance on optimization parameters. Default is 0.0
xtol_rel : absolute tolerance on optimization parameters. Default is 0.0
maxeval : maximum number of function evaluations. Default is 1e4
maxtime : maximum optimization time (in seconds). Default is 0
=#
