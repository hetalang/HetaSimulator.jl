# sim

In HetaSimulator [`sim`](@ref) method can be applied for single or multiple conditions.

## Single scenario simulation

The base `sim` method is applied for `Condition` object.
Conditions can be loaded from tables of created using [`HetaSimulator.Condition`](@ref) function.

```julia
scn1 = HetaSimulator.Condition(model; observables = [:C1, :C2], tspan = (0., 48.), parameters = [:dose => 12.])
res1 = sim(scn1; alg = Rosenbrock23())
```

The result of `sim` function execution is solution of ODE with parameters passed from (1) `Model` content and default settings, (2) settings passed from created `Condition` object and (3) additional settings from `sim` function. This function returns an object of type [`HetaSimulator.SimResults`](@ref) which stores simulated dataset in `sim` property and the original condition inside `scenario` property.

There are some specific methods for `SimResults` objects like `plot` and `DataFrame`.

```julia
plot(res1)
DataFrame(res1)
```

## Multiple scenario simulations

`sim` can be applied for many `Condition`s simultaneously.

### vector of pairs

The basic multi-scenario operation is performed for `Vector` of pairs consisting of `Symbol` identifier and `Condition`.

```julia
scenario_pairs = [
    :first => HetaSimulator.Condition(model, tspan = (0., 120.)),
    :second => HetaSimulator.Condition(model, parameters = [:dose => 20], tspan = (0., 120.))
]
res = sim(scenario_pairs)
```

The returned object is of type `Vector{Pair{Symbol, SimResults}}` which can be plotted of transformed into `DataFrame`.

### vector of scenarios

User can also use conditions without symbolic identifiers. In that case they will be generated automatically with the following rule: `_1`, `_2`, etc.

```julia
scenario_pairs = [
    HetaSimulator.Condition(model, tspan = (0., 120.)),
    HetaSimulator.Condition(model, parameters = [:dose => 20], tspan = (0., 120.))
]
res = sim(scenario_pairs)
```

### platform

`sim` method can be applied for scenarios inside `Platform` object.

```julia
res = sim(platform)
```

To simulate the selected scenarios one can use `conditions` argument.

```julia
res = sim(platform; conditions = [:scn1, :scn2])
```
