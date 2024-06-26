# [Parameters tables](@id parameters)

Parameters tables are CSV or XLSX files which store settings for parameter estimation problem.
The content of the table can be loaded into Julia environment as a `DataFrame` and used inside `fit` method.

## Format

The first row is the header. The sequence of the columns may vary.

- `parameter` : a `String` representing unique identifier of model-level parameter. The corresponding parameter must be declared in the `Model`'s namespace (`@Const` component).

- `nominal` (optional): a `Float64` nominal value which will be used as an initial value for the parameter. If it is skipped then the default value from the model will be used.

- `lower` (optional): a `Float64` value that declares the lower bound of the parameter. If skipped then the the lower bound is set to `-Inf`.

- `upper` (optional): a `Float64` value that declares the upper bound of the parameter. If skipped then the upper bound is set to `Inf`.

- `scale` (optional): `String` which can be `lin`, `log`, `logit`. The scale for parameter optimization. Default value is `lin`.

- `estimate` (optional): a `Boolean` value: `true` or `false` or numerical values `0` or `1`. Declares if the parameter should be fitted. `0` or `false` value sets the value for the parameter and excludes it from fitting. Default value is `true`.

## Usage

To load the table into Julia environment as `DataFrame` one should use `read_parameters` method. This method reads the file, checks the content and formats the data.

```julia
parameters_csv = read_parameters("./parameters.csv")
```

Currently the table can be used only in `fit` method.

```julia
fit_results = fit(p, parameters_csv)
```

## Example

Loading file __parameters.csv__ with the following content.

parameter | nominal | lower | upper | scale | estimate
---|---|---|---|---|---
sigma\_K | 0.1 | 1e-6 | 1e3 | log | 1
sigma\_P | 0.1 | 1e-6 | 1e3 | log | 1
Kp\_K\_D | 5.562383e+01 | 1e-6 | 1e3 | log | 1
Kp\_R\_D | 5.562383e+01 | 1e-6 | 1e3 | log | 0

Read as `DataFrame` object.

```julia
params = read_parameters("./parameters.csv")
res = fit(p, params)
```

As a result the `Platform` will be fitted based on all experimental data. The following parameter values will be estimated: `sigma_K`, `sigma_P`, `Kp_K_D`.

These operations are equivalent to the following.

```julia
res = fit(
    p,
    [:sigma_K => 0.1, :sigma_P => 0.1, :Kp_K_D => 5.562383e+01];
    parameters = [:Kp_R_D => 5.562383e+01],
    lbounds = [1e-6, 1e-6, 1e-6],
    ubounds = [1e3, 1e3, 1e3],
    scale = [:log, :log, :log]
)
```
