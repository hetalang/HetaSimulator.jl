# Solver choice

### Page under development. Information will be updated

## ODE solver choice

`HetaSimulator.jl` relies on [DifferentialEquations.jl](https://docs.sciml.ai/DiffEqDocs/stable/) packages, which provide access to 300+ ODE solvers. 
These solvers can be used in `HetaSimulator` simulation and parameters estimation functions (`sim`, `fit`, etc.), provided via `alg` keyword argument (for example, see [`sim`](@ref)). 
One can also set relative and absolute tolerances (`reltol`, `abstol`) and other stepsize related settings via relevant keyword arguments. See [DiffEqDocs](https://docs.sciml.ai/DiffEqDocs/stable/basics/common_solver_opts/) for details.

If no solver is provided the default one `AutoTsit5(Rosenbrock23())` will be used with `reltol=1e-3` and `abstol=1e-6` for simulation problems and `reltol=1e-6` and `abstol=1e-8` for parameters estimation.

```julia
sol = sim(
    scen; 
    alg = Rodas5P(),
    reltol=1e-6,
    abstol=1e-8
)
```

The following [DiffEq Docs page](https://docs.sciml.ai/DiffEqDocs/stable/solvers/ode_solve/) provides general advice on how to choose a solver suitable for your ODE system. 
For many ODE systems the following simplified guideline is sufficient:
1. If your system is small (~10 ODEs) go with the default solver 
2. If your system is medium-sized (~50 ODEs) choose `Rodas5P()`
3. If the system is large and stiff choose `FBDF()` or `QNDF()`
4. If `FBDF()` fails to solve the system check the model and try it again :)
5. If `FBDF()` still fails to solve the system or the integration takes too long try `CVODE_BDF()`*

*You should be cautious when using `CVODE_BDF()`. In many cases it is the fastest solver, however the accuracy of the solution is often the tradeoff. You shouldn't use it with tolerances higher than ~ `reltol=1e-4` and `abstol=1e-7`.  
