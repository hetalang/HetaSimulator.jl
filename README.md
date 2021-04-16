**HetaSimulator** is a QSP simulation engine based on Julia.


## Installation

It is assumed that you have **Julia** v1.x installed. Latest Julia release can be downloaded from [julialang.org](https://julialang.org/downloads/)

To install or update HetaSimulator and Heta compiler run:

```julia
julia> ]
(@v1.5) pkg> add https://github.com/hetalang/HetaSimulator.jl.git
julia> using HetaSimulator
julia> heta_update() # installs "Heta compiler" in NodeJS
```

## HetaSimulator: basic usage

HetaSimulator introduces three main functions: `sim`, `mc` and `fit`. 

```julia
sim(
  m::QModel, ## QModel type 
  condition;
  constants::NamedTuple=NamedTuple(), ## additional set of constants
  saveat::Union{Nothing,AbstractVector{T}}=nothing, 
  tspan::Union{Nothing,Tuple{T,T}}=nothing,
  evt_save::Tuple{Bool,Bool}=(true,true), 
  time_type=Float64,
  alg=DEFAULT_ALG, 
  reltol=DEFAULT_SIMULATION_RELTOL, 
  abstol=DEFAULT_SIMULATION_ABSTOL, 
  kwargs...
)
```
- `m` - `QModel` type
- `condition` - either `Cond` type or `Symbol` name of the condition added to the `QModel`. In case user provides vector value `HetaSimulator` will run multiple simulations. The argument also supports `Val(:all)` value to simulate all conditions added to the `QModel`
- `constants` - additional set of `constants` which will overwrite both default and condition values
- `saveat` - a collection of time points to save at. Supports `Vector` (ex. [1,2,5,10]) and `Range` (ex. `1:2:100`) values. If not provided the solution is either saved at all time points reached by the solver or at condition data points
- `tspan` - the timespan for the problem. If not provided `tspan` is set on the bases of `saveat` or condition data points
- `evt_save` - events' saving control. Default is `(true,true)`
- `alg` - ODE solver alg. Default is `AutoTsit5(Rosenbrock23())`
- `reltol` - relative tolerance. Default is `1e-3`
- `abstol` - absolute tolerance. Default is `1e-6`
- `kwargs` - other keyword arguments supported by `DiffEqBase.solve`


```julia
fit(
  m::QModel,
  condition,
  param::NamedTuple;
  ftol_abs = 0.0,
  ftol_rel = 1e-4, 
  xtol_rel = 0.0,
  xtol_abs = 0.0, 
  fit_alg = :LN_NELDERMEAD,
  maxeval = 10000,
  maxtime = 0.0,
  lbounds = fill(0.0,length(param)),
  ubounds = fill(Inf,length(param)),
  kwargs...
)
```
- `m` - `QModel` type
- `condition` - either `Cond` type or `Symbol` name of the condition added to the `QModel`. In case user provides vector value `HetaSimulator` will run multiconditional fitting. The argument also supports `Val(:all)` value to fit all conditions added to the `QModel`
- `param` - additional set of `constants` which will overwrite both default and condition values
- `ftol_abs`, `ftol_rel`, `xtol_abs`, `xtol_rel` - Fitting tolerance setup proposed in NLopt. See [NLopt README](https://github.com/JuliaOpt/NLopt.jl) for details. By default `ftol_rel = 1e-4`
- `fit_alg` - optimization algorithm supported by NLopt. Default is `:LN_NELDERMEAD`
- `maxeval` - maximum objective function evaluation before optimizer terminates. Defailt is `10000`
- `maxtime` - maximum elapsed time before optimizer terminates. By default this option is not set
- `kwargs` - other key word arguments supported by `HetaSimulator.simulate` 
 
For further usage detail see `/cases` 