# Overview of HetaSimulator.jl

The general workflow for HetaSimulator is

- Writing a modeling platform in the Heta format
- Loading platform into Julia environment
- Creating model's settings and data adding conditions and measurements
- Solve problems using the methods: sim, mc, fit
- Analyze the results

The particular workflow may be iterative, i.e. include updates to the model and re-simulation based on estimated parameters or model structure updates. It depend on the user's needs.

## Writing model in the Heta format

Heta is a modeling language for quantitative systems pharmacology and systems biology.
It is a DSL (domain-specific language) describing dynamic model or models in process-description format.
Heta compiler converts it into variety of files including "Julia" format which can be loaded to Julia/HetaSimulator environment.

HetaSimulator supports all features of the [Heta language](https://hetalang.github.io/#/specifications/). So one can organize modeling project as re-used modules (files), include any number of models into single platform with the namespaces mechanism. The platform can use the declaration file __platform.json__ or can be loaded from single file. 
All Heta modules: Heta code, tables, SBML and JSON can be loaded as a modeling platform and compiled into ODE-based mathematical representation.

To read more about Heta-based modeling platforms and Heta compiler visit the homepage <https://hetalang.github.io/#/>.

As an example we will use a model describing a simple pharmacokinetic model stored in single __.heta__ file. It is expected that the model code will be placed into "index.heta" file located in a directory __my_example__ or something like that.

```julia
// Compartments
Vol0 @Compartment .= 1;
Vol1 @Compartment .= 6.3;
Vol2 @Compartment .= 10.6;

// Species
A0 @Species {compartment: Vol0, isAmount: true} .= 0;
C1 @Species {compartment: Vol1} .= 0;
C2 @Species {compartment: Vol2} .= 0;

// Reactions
v_abs @Reaction {actors: A0 = C1} := kabs * A0;
v_el @Reaction {actors: C1 =} := Vol1 * (kel * C1); // Vol1 * (kmax * C1 / (Km + C1));
v_distr @Reaction {actors: C1 = C2} := Q * (C1 - C2);

// Parameters
dose @Const = 20;
kabs @Const = 10;
kel @Const = 0.2;
Q @Const = 3.2;

// single dose event
sw1 @TimeSwitcher {start: 0};
A0 [sw1]= dose;

// multiple dose event, default off
sw2 @TimeSwitcher {start: 0, period: 24, active: false};
A0 [sw2]= dose;
```

The model describes a typical two-compartment model with single or multiple dose depending on which event is active.
Take a note that the component of the model is create without any `namespace` statement. This means they have the default namespace attribute `nameless`.
This code is equivalent to the following system of ODE.

```math
\begin{aligned}
&\frac{d}{dt}A_0 = - v_{abs}\\
&\frac{d}{dt}(C_1 \cdot Vol_1) = v_{abs} - v_{el} - v_{distr}\\
&\frac{d}{dt}(C_2 \cdot Vol_2) = v_{distr}\\
\\
&A_0(0) = 0\\
&C_1(0) = 0\\
&C_2(0) = 0\\
&v_{abs}(t) = kabs \cdot A_0\\
&v_{el}(t) = Vol_1 \cdot (kel \cdot C_1)\\
&v_{distr}(t) = Q \cdot (C_1 - C_2)\\
\end{aligned}\\
\\
\text{event at } t = 0\\
\\
A_0 = dose
```

Where parameters are

```math
\begin{aligned}
&dose = 20\\
&kabs = 10\\
&kel = 0.2\\
&Q  = 3.2\\
&Vol_1 = 6.3\\
&Vol_2 = 10.6\\
\end{aligned}\\
```

## Loading platform from the Heta format

HetaSimulator loads modeling platform into `Platform` type object that is a container for all models simulation settings and experimental data. When you load a platform from Heta it includes only models converted from `concrete namespaces`. The condition storage is empty and will be populated manually or imported from tables.

### Loading with internal compiler

When __HetaSimulator__ is installed and internal __Heta compiler__ is installed the platform can be loaded with the method [`load_platform`](@ref).

```julia
using HetaSimulator

p = load_platform("./my_example")
```

```julia
No declaration file, running with defaults...
[info] Builder initialized in directory "Y:\HetaSimulator.jl\cases\story_3".
[info] Compilation of module "index.heta" of type "heta"...
[info] Reading module of type "heta" from file "Y:\HetaSimulator.jl\cases\story_3\index.heta"...
[info] Setting references in elements, total length 50
[info] Checking for circular references in Records.
[warn] Units checking skipped. To turn it on set "unitsCheck: true" in declaration.
[info] Checking unit's terms.
[warn] "Julia only" mode
[info] Exporting to "Y:\HetaSimulator.jl\cases\story_3\_julia" of format "Julia"...
Compilation OK!
Loading platform... OK!
+---------------------------------------------------------------------------
| Platform contains:
|   1 model(s): nameless. Use `models(platform)` for details.
|   0 condition(s): . Use `conditions(platform)` for details.
+---------------------------------------------------------------------------
```

The first argument of `load_platform` declares the absolute or relative path to the platform directory.
If you use another file name (not __index.heta__) you can declare it with `source` argument.

```julia
p = load_platform("./my_example", source = "another_name.heta")
```

You can also load the model from another formats like SBML.

```julia
p = load_platform("./another_project", source = "model.xml", type = "SBML")
```
The list of additional arguments is approximately the same as [CLI options](https://hetalang.github.io/#/heta-compiler/cli-references?id=quotheta-buildquot-command) of `heta build` command of Heta compilers. For the full list see [`load_platform`](@ref) references.

### Loading pre-compiled platform

Alternatively you can use files generated with stand-alone [Heta compiler](https://hetalang.github.io/#/heta-compiler/).

To do so the model code should be updated with the following statement.

```heta
...
sw2 @TimeSwitcher {start: 0, period: 24, active: false};
A0 [sw2]= dose;

#export {format: Julia, filepath: julia_platform};
```

Running the code with the console command `heta build my_project` produces the file __my_project/dist/julia_platform/model.jl__ which can be loaded with [`load_jlplatform`](@ref) method.

```julia
p = load_jlplatform("./my_example/dist/julia_platform/model.jl")
```
```julia
Loading platform... OK!
+---------------------------------------------------------------------------
| Platform contains:
|   1 model(s): nameless. Use `models(platform)` for details.
|   0 condition(s): . Use `conditions(platform)` for details.
+---------------------------------------------------------------------------
```

## Creating conditions


### Import from CSV tables

### Import from excell tables

### Manual creation
