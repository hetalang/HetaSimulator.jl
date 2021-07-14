# sim method

In HetaSimulator [`sim`](@ref) method can be applied for single or multiple conditions.

## Single condition simulation

The base `sim` method is applied for `Condition` object.
Conditions can be loaded from tables of created using [`Condition`](@ref) function.

```julia
cond1 = HetaSimulator.Condition(model; observables = [:C1, :C2], tspan = (0., 48.), parameters = [:dose => 12.])
res1 = sim(cond1; alg = Rosenbrock23())
```

The result of `sim` function execution is solution of ODE with parameters passed from (1) `Model` content and default settings, (2) settings passed from created `Condition` object and (3) additional settings from `sim` function. This function returns an object of type `SimSolution` which stores simulated dataset in property `sim` and the original condition inside property `cond`.

There are some specific methods for `SimSolution` objects like `plot` and `DataFrame`.

```julia
plot(res1)
DataFrame(res1)
```

`sim` can also be applied for `Model` without explicit creation of `Condition`.
In that case you can pass all settings into `sim` function.
`Condition` object will be created in the same manner.
The next code get the same results as previously.

```julia
res1 = sim(model; observables = [:C1, :C2], tspan = (0., 48.), parameters = [:dose => 12.], alg = Rosenbrock23())
plot(res1)
```

The first approach is useful when you need to store different conditions applied for the same model and simulate them when required.
The second approach is more compact and can be used for some preliminary simulation experiments.

## Multiple condition simulations

