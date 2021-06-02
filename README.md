[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://hetalang.github.io/HetaSimulator.jl/dev/)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/HetaSimulator.jl.svg)](https://GitHub.com/hetalang/HetaSimulator.jl/issues/)
[![Documentation](https://github.com/hetalang/HetaSimulator.jl/actions/workflows/gh-pages.yml/badge.svg)](https://github.com/hetalang/HetaSimulator.jl/actions/workflows/gh-pages.yml)
[![Coverage Status](https://coveralls.io/repos/github/hetalang/HetaSimulator.jl/badge.svg?branch=master)](https://coveralls.io/github/hetalang/HetaSimulator.jl?branch=master)
[![GitHub license](https://img.shields.io/github/license/hetalang/HetaSimulator.jl.svg)](https://github.com/hetalang/HetaSimulator.jl/blob/master/LICENSE)

# HetaSimulator

**HetaSimulator** is an OpenSource simulation and parameters estimation (fitting) platform for the [Heta modeling language](https://hetalang.github.io/#/). 
The main purpose of the package is to establish the linkage between emerging [QSP frameworks](https://en.wikipedia.org/wiki/Quantitative_systems_pharmacology) and fast computational methods (parallel simulations, automatic differentiation, etc.).

## Introduction

Heta language is a domain-specific modeling language (DSL) for dynamic quantitative models used in quantitative systems pharmacology (QSP) and systems biology (SB). Heta code and tabular formats can be translated into [variety of formats](https://hetalang.github.io/#/heta-compiler/?id=supported-tools) like Simbiology, Matlab, mrgsolve, DBSolve and many others.

This package provides the simulation engines for the Heta-based models and modeling platforms. The model can be directly run using the HetaSimulator without additional tools. The ODE system in general form can also be run with HetaSimulator.

Internally HetaSimulator utilizes the facilities of OpenSource projects like [Julia](https://julialang.org/) and [SciML ecosystem](https://sciml.ai/).

## Installation

It is assumed that you have **Julia** v1.6 installed. The latest Julia release can be downloaded from [julialang.org](https://julialang.org/downloads/)

To install or update HetaSimulator and Heta compiler run:

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

Create a model in Heta format or use you Heta based platform.
Here we will use the example with a simple model with two species and one reaction.

```heta
// index.heta file in directory "my_project"
comp1 @Compartment .= 1.5;

s1 @Species {compartment: comp1, output: true} .= 12;
s2 @Species {compartment: comp1, output: true} .= 0;

r1 @Reaction {actors: s1 => s2, output: true} := k1 * s1 * comp1;

k1 @Const = 1e-3;
```

*To read more about Heta code read [Heta specifications](https://hetalang.github.io/#/specifications/)*

```julia
using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("./my_project") # wait for the model compilation...

# get the base Heta model
model = platform.models[:nameless]

# single simulation and plot
results = sim(model; tspan = (0., 1200.))
plot(results)

# transform to data frame
df = DataFrame(results)
```

## Known issues and limitations

## Getting help

## Contributing

## License

This package is distributed under the terms of the [MIT License](./LICENSE).

Copyright 2020-2021, InSysBio LLC
