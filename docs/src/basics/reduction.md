# Using `reduction_func` and `output_func`

When running multiple simulations (Monte Carlo or “virtual patient” simulations) with the `mc()` or `sim` functions, you can customize how results are collected using output functions and reduction functions. These optional callbacks let you control what data each simulation returns and how multiple simulation outputs are aggregated:

- `output_func(sol, i)` – A function that determines what is saved from each individual simulation’s result. By default, it saves the entire simulation result object. You can override this to save a specific value or summary from each run (it returns a tuple (output, rerun_flag)).

- `reduction_func(u, batch, I)` – A function that determines how to combine or filter the outputs from batches of simulations. By default, it simply appends each simulation’s output to an array. You can override this to aggregate results (e.g. filtering or computing statistics) as simulations complete (it returns (updated_accumulator, stop_flag)).


## `output_func` examples

### Saving individual simulation's results

This `output_func` saves each simulation result `sol` as a CSV file named by its index `i`. The simulation result is converted to a `DataFrame` and written to `"sol_i.csv"`. Since we write to disk we don't need to keep the result in memory.

```julia
using HetaSimulator, CSV, DataFrames

platform = load_platform("$HetaSimulatorDir/test/examples/single_comp")
model = platform.models[:nameless]

sc1 = Scenario(model, (0., 200.), observables=[:r1])

function output_func1(sol, i)
  CSV.write("sol_$i.csv", DataFrame(sol))
  return (nothing, false)
end

mc1 = mc(sc1, [:k1=>Normal(0.02,1e-3)], 5; output_func=output_func1)
```

## `reduction_func` examples

There arу two  keyword arguments to `mc()` or `sim` that control how results are processed in batches:
- `batch_size` - The number of simulations in each batch passed to `reduction_func`. Defaults to the total number of simulations.
- `pmap_batch_size` - The number of simulations distributed per worker (if using `EnsembleDistributed`).  Defaults to `batch_size÷100 > 0 ? batch_size÷100 : 1`.

For more details, see the [SciML docs](https://docs.sciml.ai/DiffEqDocs/dev/features/ensemble)

### Saving batches of simulations

This `reduction_func` saves each batch of simulations to disk as a CSV file, using the batch index range (e.g., `sol_1_10.csv`). The batch of results is wrapped in an `MCResult` object to convert it to a `DataFrame`.

```julia
using HetaSimulator, CSV, DataFrames

platform = load_platform("$HetaSimulatorDir/test/examples/single_comp")
model = platform.models[:nameless]

sc1 = Scenario(model, (0., 200.), observables=[:r1])

function reduction_func1(u,batch,I)
  mcres_batch = HetaSimulator.MCResult(batch, true, nothing)
  df_batch = DataFrame(mcres_batch)
  CSV.write("sol_$(first(I))_$(last(I)).csv", df_batch)
  
  (u, false)
end

mc1 = mc(sc1, [:k1=>Normal(0.02,1e-3)], 100; batch_size=10, reduction_func=reduction_func1)
```

### Filtering plausible simulation results

This `reduction_func` filters out simulations where the value of observable `:r1` at `t=200`.0 is not greater than 0.004. Only simulations meeting this criterion are pushed into the accumulator `u`. After all simulations, `u` will contain only the filtered subset.

```julia
using HetaSimulator, CSV, DataFrames

platform = load_platform("$HetaSimulatorDir/test/examples/single_comp")
model = platform.models[:nameless]

sc1 = Scenario(model, (0., 200.), observables=[:r1])

function reduction_func2(u, batch, I)
  for s in batch
    t1 = 200.
    var = :r1
    if s(t1, var) > 0.004
      push!(u, s)
    end
  end
  (u,false)
end

mc1 = mc(sc1, [:k1=>Normal(0.02,1e-3)], 100; reduction_func=reduction_func2)
```

