# Overview of HetaSimulator.jl

The general workflow for HetaSimulator is

- Writing model in Heta format
- Loading model
- Creating model settings and data using conditions and measurements
- Solve problems
- Analyze the results.

The particular workflow may be iterative, i.e. include updates to the model and re-simulation based on estimated parameters or model structure updates.

## Writing model in Heta format

Heta is a modeling language for quantitative systems pharmacology and systems biology.
To read more about Heta based modeling platforms and Heta compiler visit the homepage <https://hetalang.github.io/#/>.

The Heta language is DSL (domain-specific language) describing dynamic model or models in process-description format.
Heta compiler converts it into variety of files including "Julia" format which can be loaded to HetaSimulator engine.

As an example we will use a model describing a simple pharmacokinetic model. It is expected that the model code will be placed into "index.heta" file located in some directory "my_example" or something like that.

```julia
comp1 @Compartment .= 1;
c1 @Species {compartment: comp1} .= 10;

comp2 @Compartment .= 2;
c2 @Species {compartment: comp2} .= 0;
a2 @Species {compartment: comp2, isAmount: true} .= 0;

comp3 @Compartment .= 3;
c3 @Species {compartment: comp3} .= 0;

// reactions
r1 @Reaction {actors: c1 = c2} := k1 * c1 * comp1;
r2 @Reaction {actors: c2 = c3 + a2} := k2 * c2 *comp2;
r3 @Reaction {actors: c3 = } := k3 * c3 * comp3;

// constants
k1 @Const = 0.01;
k2 @Const = 0.02;
k3 @Const = 0.03;

#export {format: Matlab, filepath: model};
```

## Loading model from Heta format

Currently HetaSimulator supports models in [Heta formats](https://hetalang.github.io/#/specifications/).
All Heta modules: Heta code, tables, SBML and JSON can be loaded as a modeling platform using internal compiler.
Alternatively you can use files generated with stand-alone [Heta compiler](https://hetalang.github.io/#/heta-compiler/).

### 
