**HetaSimulator** is an OpenSource simulation and parameters estimation (fitting) platform for the [Heta modeling language](https://hetalang.github.io/#/). 
The main purpose of the package is to establish the linkage between emerging [QSP frameworks](https://en.wikipedia.org/wiki/Quantitative_systems_pharmacology) and fast computational methods (parallel simulations, automatic differentiation, etc.).

## Introduction

Heta language is a domain-specific modeling language (DSL) for dynamic quantitative models used in quantitative systems pharmacology (QSP) and systems biology (SB). Heta code and tabular formats can be translated into [variety of formats](https://hetalang.github.io/#/heta-compiler/?id=supported-tools) like Simbiology, Matlab, mrgsolve, DBSolve and many others.

This package provides the simulation engines for the Heta-based models and modeling platforms to be run in Julia. A QSP model can be directly run using the HetaSimulator without additional tools. The ODE system in general form can also be run with HetaSimulator.

Internally HetaSimulator utilizes the facilities of OpenSource projects like [Julia](https://julialang.org/) and [SciML ecosystem](https://sciml.ai/).

## Installation

It is assumed that you have **Julia** v1.6 installed. The latest Julia release can be downloaded from [julialang.org](https://julialang.org/downloads/)

To install or update HetaSimulator and Heta compiler run the code below in Julia environment:

```julia
julia> ]
(@v1.6) pkg> add https://github.com/hetalang/HetaSimulator.jl.git
julia> using HetaSimulator
julia> heta_update() # installs "Heta compiler" in NodeJS
```

Internally HetaSimulator uses Heta compiler which is installed inside the package. If you want to update it to the last version just run.
```julia
julia> heta_update() # updates to the latest stable version
```

## Basic usage

Create a model in Heta format or use your Heta-based platform.
Here we will use the example with a simple model with two species and one reaction.

```heta
// index.heta file in directory "my_project"
comp1 @Compartment .= 1.5;

s1 @Species {compartment: comp1, output: true} .= 12;
s2 @Species {compartment: comp1, output: true} .= 0;

r1 @Reaction {actors: s1 => s2, output: true} := k1 * s1 * comp1;

k1 @Const = 1e-3;
```

*To read more about Heta read [Heta specifications](https://hetalang.github.io/#/specifications/)*

```julia
using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("./my_project")
# wait for the platform compilation...

# get the default Heta model
model = platform.models[:nameless]

# single simulation and plot
results = sim(model; tspan = (0., 1200.))
plot(results)
```

![Plot](https://raw.githubusercontent.com/hetalang/HetaSimulator.jl/master/plot0.png)

```julia
# transform results to data frame
df = DataFrame(results)
...
9×4 DataFrame
 Row │ t             s1        s2           scope  
     │ Float64       Float64   Float64      Symbol 
─────┼─────────────────────────────────────────────
   1 │    0.0555525  11.9993   0.000666611  ode_
   2 │    0.611077   11.9927   0.00733069   ode_
```

## Architecture

The user of HetaSimulator typically deals with the following three types:
- `Model` - an ODE model, containing rhs, rules, initial parameters and vector of events.
- `Cond` - condition representing a special model's setup for simulations or fitting. This setup can include initial parameters and events settings, output variables etc. In case of fitting `Cond` should also include experimental data. A common usage of `Cond` can be model's simulation with different drugs (parameters and events setup). Different `Cond`'s can be united to run multi-conditional simulations and fitting.
- `Platform` - container for different `Model`s and `Cond`s.

The user can perform the following three operations with both `Model`, `Cond` and `Platform`
- `sim` - run a single or multi-conditional simulations. 
- `fit` - fit a model to experimental data. 
- `mc` - run Monte-Carlo or virtual patients simulations.

See documentation for detailed overview of **HetaSimulator** types and functions' arguments.

## Known issues and limitations

- Currently the HetaSimulator package is not published on Julia repository, use the direct link to install 
   ```julia
   ] add https://github.com/hetalang/HetaSimulator.jl
   ```

## Getting help

- Read the [docs](https://hetalang.github.io/HetaSimulator.jl/dev/)
- Use [Gitter Chatroom](https://gitter.im/hetalang/community?utm_source=readme).
- Use [Issue Tracker](https://github.com/hetalang/HetaSimulator.jl/issues)

## License

This package is distributed under the terms of the **MIT License**.

Copyright 2020-2021, InSysBio LLC

## Authors and history

- Ivan Borisov
- Evgeny Metelkin

**HetaSimulator** is inspired by the user experience of the software packages like [SBMLToolbox](http://sbml.org/Software/SBMLToolbox), [mrgsolve](https://mrgsolve.github.io/), [DBSolve](http://insysbio.com/en/software/db-solve-optimum), [dMod](https://github.com/dkaschek/dMod).

The package utilizes the unique features of [Julia](https://julialang.org/) and [SciML ecosystem](https://sciml.ai/).
