[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![version](https://img.shields.io/github/v/release/hetalang/HetaSimulator.jl?label=version)](https://platform.juliahub.com/ui/Packages/General/HetaSimulator)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/HetaSimulator.jl.svg)](https://GitHub.com/hetalang/HetaSimulator.jl/issues/)
[![Coverage Status](https://coveralls.io/repos/github/hetalang/HetaSimulator.jl/badge.svg?branch=master)](https://coveralls.io/github/hetalang/HetaSimulator.jl?branch=master)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://hetalang.github.io/HetaSimulator.jl/stable)
[![GitHub license](https://img.shields.io/github/license/hetalang/HetaSimulator.jl.svg)](https://github.com/hetalang/HetaSimulator.jl/blob/master/LICENSE)

# HetaSimulator

**HetaSimulator** is a Julia‑based simulation engine for models written
in the [Heta modeling language](https://hetalang.github.io).\
It is part of the **Heta project** and enables fast
simulations and analysis using the Julia [SciML](https://sciml.ai/)
ecosystem.

📚 **Full documentation:**\
<https://hetalang.github.io/HetaSimulator.jl/stable>

## Quick start

The example below creates a simple reaction model and runs a simulation.

### 1. Create a project directory
`
Create a new directory called **heta-simulation**

### 2. Create a model file

Create a file **`index.heta`** inside the directory:

```heta
comp1 @Compartment .= 1;

A @Species { compartment: comp1 } .= 10;
B @Species { compartment: comp1 } .= 0;
r1 @Reaction { actors: A => 2B } := k1 * A * comp1;

k1 @Const = 1.2e-1;
```

This model describes a simple reaction converting **A → B** inside a
compartment.

### 3. Create a simulation script

Create a file **`run.jl`**:

``` julia
using HetaSimulator, Plots

# load platform from the directory
# index.heta is the default entry point
platform = load_platform(".")
model = models(platform)[:nameless]

# create simulation scenario
scenario = Scenario(model, (0., 100.); observables = [:A, :B])

# simulate and plot results
results = sim(scenario)
plot(results)
```

### 4. Run the simulation

Run the script in Julia. You should see a plot showing the dynamics of species **A** and **B**.

![Simulation result](./plot0.png)

## Installation

Make sure **Julia** is installed: <https://julialang.org/downloads/>

Then install the package in the Julia package manager:

``` julia
julia> ]
pkg> add HetaSimulator
```

## About Heta

[Heta](https://hetalang.github.io) is a domain‑specific modeling
language (DSL) for dynamic models used in quantitative systems
pharmacology (QSP) and systems biology.

HetaSimulator provides the Julia‑based simulation engine for running and
analyzing these models.

## Getting help

-   Documentation: <https://hetalang.github.io>
-   Issue tracker: <https://github.com/hetalang/HetaSimulator.jl/issues>

## Reproducibility reports

This section presents automated HetaSimulator.jl simulation checks for the
`master` branch. Each selected SBML Semantic Test Suite case is loaded by
HetaSimulator.jl and compared with its reference time course.

| Test set | Simulation check | Latest `master` |
| --- | --- | --- |
| sbmlteam/sbml-test-suite | SBML L2V5 → model.jl → HetaSimulator.jl | [![SBML L2V5 HetaSimulator simulation](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FHetaSimulator.jl%2Freports%2Fhetasimulator-simulation%2Fbranches%2Fmaster%2Fl2v5%2Fbadge.json)](https://hetalang.github.io/format-conversion-test-suite/report/?ref=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FHetaSimulator.jl%2Freports%2Fhetasimulator-simulation%2Fbranches%2Fmaster%2Fl2v5%2Freport.json) |
| sbmlteam/sbml-test-suite | SBML L3V1 → model.jl → HetaSimulator.jl | [![SBML L3V1 HetaSimulator simulation](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FHetaSimulator.jl%2Freports%2Fhetasimulator-simulation%2Fbranches%2Fmaster%2Fl3v1%2Fbadge.json)](https://hetalang.github.io/format-conversion-test-suite/report/?ref=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FHetaSimulator.jl%2Freports%2Fhetasimulator-simulation%2Fbranches%2Fmaster%2Fl3v1%2Freport.json) |

## License

This project is distributed under the terms of the **MIT License**.

_This software is provided "as is", without any warranties or guarantees. Use it at your own risk. The author is not responsible for any issues, data loss, or damages resulting from its use._

Copyright © 2020-2026 Heta project
