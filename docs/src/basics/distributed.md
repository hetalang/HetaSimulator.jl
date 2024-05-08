# Parallel simulations

`HetaSimulator` supports parallel simulations on a single machine and in a distributed (cluster) environment. It can be achieved by setting up `Julia workers`.
`Distributed` package can be used to start workers on a local machine and [ClusterManagers](https://github.com/JuliaParallel/ClusterManagers.jl) package supports a number of job queue systems (SGE, PBS, HTCondor, etc). In the following examples we will use `Distributed` package to start `workers`. `HetaSimulator` implementation of parallel simulations relies on [SciML Ensemble Simulations](https://diffeq.sciml.ai/stable/features/ensemble/) features and inherits [EnsembleAlgorithms](https://diffeq.sciml.ai/stable/features/ensemble/#EnsembleAlgorithms) choice. Parallelization algorithm is defined by `parallel_type` keyword argument. Currently it supports the following options:
- `EnsembleSerial()` - No parallelism. The default. 
- `EnsembleThreads()` - This uses multithreading. It's local (single computer, shared memory) parallelism only.
- `EnsembleDistributed()` - Uses pmap internally. It will use as many processors as you have Julia processes.


## Parallelization types

### Simulating Scenarios in Parallel

Assuming we have loaded a number of `Scenario`s: `scn1, scn2, scn3` we parallelize simulation or fitting procedures. 

```julia
using Distributed
addprocs(2)
@everywhere using HetaSimulator

s = sim([scn1, scn2, scn3], parallel_type=EnsembleDistributed())
f = fit([scn1, scn2, scn3], [:k1=>0.1,:k2=>0.2,:k3=>0.3], parallel_type=EnsembleDistributed())
```

### Parallel Monte Carlo Simulations

We can run parallel Monte-Carlo (Ensemble) simulations with parameters taken from distributions or from a pre-generated `DataFrame`.
Parallel setup can work both with parameters vectors and `scenarios`. 
Let's assume we have loaded a number of `Scenario`s: `scn1, scn2, scn3` and a `DataFrame` `df` with parameters vectors (as rows).
```julia
using Distributed
addprocs(2)
@everywhere using HetaSimulator

s1 = mc(scn1, df, 150, parallel_type=EnsembleDistributed())
s2 = mc([scn1, scn2, scn3], [:k2=>Normal(1e-3,1e-4), :k3=>Normal(1e-4,1e-5)], 150, parallel_type=EnsembleDistributed())
```

