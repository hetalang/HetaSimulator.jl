[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![version](https://juliahub.com/docs/HetaSimulator/version.svg)](https://juliahub.com/ui/Packages/HetaSimulator/IIE0h)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/HetaSimulator.jl.svg)](https://GitHub.com/hetalang/HetaSimulator.jl/issues/)
[![Coverage Status](https://coveralls.io/repos/github/hetalang/HetaSimulator.jl/badge.svg?branch=master)](https://coveralls.io/github/hetalang/HetaSimulator.jl?branch=master)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://hetalang.github.io/HetaSimulator.jl/stable)
[![GitHub license](https://img.shields.io/github/license/hetalang/HetaSimulator.jl.svg)](https://github.com/hetalang/HetaSimulator.jl/blob/master/LICENSE)

# HetaSimulator

**HetaSimulator** is an open-source simulation and parameters estimation (fitting) platform for the [Heta modeling language](https://hetalang.github.io/#/). 
The main purpose of the package is to establish the linkage between emerging [QSP frameworks](https://en.wikipedia.org/wiki/Quantitative_systems_pharmacology) and fast computational methods (parallel simulations, automatic differentiation, etc.).

The latest documentation can be found here: <https://hetalang.github.io/HetaSimulator.jl/stable/>.

See the [ROAD MAP](./roadmap.md) for upcoming updates.

## Introduction

Heta language is a domain-specific modeling language (DSL) for dynamic models used in quantitative systems pharmacology (QSP) and systems biology (SB). Heta models can be translated into [variety of formats](https://hetalang.github.io/#/heta-compiler/?id=supported-tools) like Simbiology, Matlab, mrgsolve, DBSolve and many others.

This package provides the Julia-based simulation engine for Heta-based models and modeling platforms. Users can simulate QSP models in heta format as well as ODE systems in general form using HetaSimulator without additional tools.

Internally HetaSimulator utilizes the features of open-source software like [Julia](https://julialang.org/) and [SciML ecosystem](https://sciml.ai/).

## Installation

It is assumed that you have **Julia** installed. The latest Julia release can be downloaded from [julialang.org](https://julialang.org/downloads/)

To install or update HetaSimulator and heta-compiler run the code below in Julia environment:

```julia
julia> ]
pkg> add HetaSimulator
```
Notes:
 - Internally HetaSimulator installs Heta compiler as an artifact. 
 - In some MacOS versions, the installation of the package may require Rosetta, use `softwareupdate --install-rosetta` in terminal.

## Basic usage

Create a model in Heta format or use your Heta-based platform.
Here we will use a simple model with two species and one reaction.

```heta
// index.heta file in directory "my_project"
comp1 @Compartment .= 1.5;

s1 @Species {compartment: comp1, output: true} .= 12;
s2 @Species {compartment: comp1, output: true} .= 0;

r1 @Reaction {actors: s1 => s2, output: true} := k1 * s1 * comp1;

k1 @Const = 1e-3;
```

*To learn more about Heta DSL read [Heta specifications](https://hetalang.github.io/#/specifications/)*

```julia
using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("./my_project")
# wait for the platform compilation...

# get the base Heta model
model = platform.models[:nameless]

# single simulation and plot
results = Scenario(model, (0., 1200.)) |> sim
plot(results)
```

![Plot](https://raw.githubusercontent.com/hetalang/HetaSimulator.jl/master/plot0.png)

```julia
# convert results to data frame
df = DataFrame(results)
...
9×4 DataFrame
 Row │ t             s1        s2           scope  
     │ Float64       Float64   Float64      Symbol 
─────┼─────────────────────────────────────────────
   1 │    0.0555525  11.9993   0.000666611  ode_
   2 │    0.611077   11.9927   0.00733069   ode_
```

*To read more about available functions, see the [documentation](https://hetalang.github.io/HetaSimulator.jl/stable/)*

## Getting help

- Read the [docs](https://hetalang.github.io/HetaSimulator.jl/stable/)
- Use [Gitter Chatroom](https://gitter.im/hetalang/community?utm_source=readme).
- Use [Issue Tracker](https://github.com/hetalang/HetaSimulator.jl/issues)

## Contributing

- [Source Code](https://github.com/hetalang/HetaSimulator.jl)
- [Issue Tracker](https://github.com/hetalang/HetaSimulator.jl/issues)
- See also contributing in [Heta project](https://hetalang.github.io/#/CONTRIBUTING)

## License

This package is distributed under the terms of the [MIT License](./LICENSE).

Copyright 2020-2024, InSysBio LLC
