# Solver choice

## ODE solver choice

`HetaSimulator.jl` relies on the [SciML](https://docs.sciml.ai/DiffEqDocs/stable/) solver ecosystem.
Solvers can be used in `HetaSimulator` simulation and parameter estimation functions (`sim`, `fit`, etc.) via the `alg` keyword argument (for example, see [`sim`](@ref)).
One can also set relative and absolute tolerances (`reltol`, `abstol`) and other stepsize-related settings via relevant keyword arguments. See [DiffEqDocs](https://docs.sciml.ai/DiffEqDocs/stable/basics/common_solver_opts/) for details.

If no solver is provided the default one `AutoTsit5(Rosenbrock23())` will be used with `reltol=1e-3` and `abstol=1e-6` for simulation problems and `reltol=1e-6` and `abstol=1e-8` for parameters estimation.

Starting from `OrdinaryDiffEq.jl` v7, solvers are distributed through smaller subpackages.
`HetaSimulator.jl` includes and reexports a focused set of these packages:

| Package | Example solvers available after `using HetaSimulator` |
| --- | --- |
| `OrdinaryDiffEqTsit5` | `Tsit5()`, `AutoTsit5(...)` |
| `OrdinaryDiffEqRosenbrock` | `Rosenbrock23()`, `Rodas5P()` |
| `OrdinaryDiffEqBDF` | `FBDF()`, `QNDF()` |
| `OrdinaryDiffEqSDIRK` | `TRBDF2()`, `KenCarp4()`, `Kvaerno5()` |

This means common nonstiff, stiff, BDF, Rosenbrock, and SDIRK methods can be used directly:

```julia
sol = sim(
    scen; 
    alg = Rodas5P(),
    reltol=1e-6,
    abstol=1e-8
)
```

To use a solver from another SciML package, add that package to your Julia environment and load it together with `HetaSimulator`.
For example, Verner methods are provided by `OrdinaryDiffEqVerner`:

```julia
using Pkg
Pkg.add("OrdinaryDiffEqVerner")

using HetaSimulator
using OrdinaryDiffEqVerner

sol = sim(scen; alg = Vern7())
```

Similarly, SUNDIALS solvers such as `CVODE_BDF()` are provided by `Sundials.jl`:

```julia
using Pkg
Pkg.add("Sundials")

using HetaSimulator
using Sundials

sol = sim(scen; alg = CVODE_BDF())
```

For distributed simulations, load any additional solver package on all workers, for example with `@everywhere using OrdinaryDiffEqVerner`.

The following [DiffEq Docs page](https://docs.sciml.ai/DiffEqDocs/stable/solvers/ode_solve/) provides general advice on how to choose a solver suitable for your ODE system. 
For many ODE systems the following simplified guideline is sufficient:
1. If your system is small (~10 ODEs) go with the default `AutoTsit5(Rosenbrock23())` solver
2. If your system is medium-sized (~50 ODEs) choose `Rodas5P()`
3. If the system is large and stiff choose `FBDF()` or `QNDF()`
4. If `FBDF() / QNDF()` fails to solve the system check the model and try it again :)
5. If `FBDF() / QNDF()` still fails to solve the system or the integration takes too long try using `CVODE_BDF()` from `Sundials.jl`*.

*You should be cautious when using `CVODE_BDF()`. In many cases it is the fastest solver, however the accuracy of the solution is often the tradeoff. You shouldn't use it with tolerances higher than ~ `reltol=1e-4` and `abstol=1e-7`.  
