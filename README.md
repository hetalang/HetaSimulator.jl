## Overview

**HetaSimulator** is a simulation and parameters estimation (fitting) platform for [Heta modeling language](https://hetalang.github.io/#/). The main purpose of the platform is to establish the linkage between emerging [QSP frameworks](https://en.wikipedia.org/wiki/Quantitative_systems_pharmacology) and fast computational methods (parallel simulations, automatic differentiation, etc.). **HetaSimulator** is inspired by the user experience of the software packages like [SBMLToolbox](http://sbml.org/Software/SBMLToolbox), [mrgsolve](https://mrgsolve.github.io/), [DBSolve](http://insysbio.com/en/software/db-solve-optimum), [dMod](https://github.com/dkaschek/dMod). From the computational point of view, it utilizes the unique features of [Julia](https://julialang.org/) and [SciML ecosystem](https://sciml.ai/).

## Installation

It is assumed that you have **Julia** v1.6 installed. Latest Julia release can be downloaded from [julialang.org](https://julialang.org/downloads/)

To install or update HetaSimulator and Heta compiler run:

```julia
julia> ]
(@v1.6) pkg> add https://github.com/hetalang/HetaSimulator.jl.git
julia> using HetaSimulator
julia> heta_update() # installs "Heta compiler" in NodeJS
```

## Introduction

The user of HetaSimulator typically deals with the following three types:
- `Model` - an ODE model, containing rhs, rules, initial parameters and vector of events.
- `Cond` - condition representing a special model's setup for simulations or fitting. This setup can include initial parameters and events settings, output variables etc. In case of fitting `Cond` should also include experimental data. A common usage of `Cond` can be model's simulation with different drugs (parameters and events setup). Different `Cond`'s can be united to run multi-conditional simulations and fitting.
- `Platform` - container for different `Model`s and `Cond`s.

The user can perform the following three operations with both `Model`, `Cond` and `Platform`
- `sim` - run a single simulation or multi-conditional simulations. 
- `fit` - fit a model to experimental data. 
- `mc` - run Monte-Carlo or virtual patients simulations.

See documentation for detailed overview of **HetaSimulator** types and functions' arguments.

## Basic usage

A basic use-case example is provided in /cases/story_1 folder

```julia
using HetaSimulator, Plots

platform = load_platform("$HetaSimulatorDir/cases/story_1", rm_out=false);
model = platform.models[:nameless]

## single simulation
sim(model; tspan = (0., 200.)) |> plot #1

## condition simulation
cond1 = Cond(model; tspan = (0., 200.), events_on=[:ss1 => false], saveat = [0.0, 150., 250.]);
sim(cond1) |> plot

## fitting
measurements_csv = read_measurements("$HetaSimulatorDir/cases/story_1/measurements.csv")
cond4 = Cond(model; constants = [:k2=>0.001, :k3=>0.04], events_on=[:ss1 => false], saveat = [0.0, 50., 150., 250.]);
add_measurements!(cond4, measurements_csv; subset = Dict(:condition => :dataone))


```