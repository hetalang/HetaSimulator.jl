# Parameters tables

Parameters tables are CSV or XLSX files which store settings for parameter identification problems.
The content of the table can be loaded into Julia environment as a `DataFrame` to be used inside `fit` method.

## Format

The first row is intended for headers which clarify the columns meaning. The sequence of columns is not important.

- `parameter` : a `String` representing unique identifier of constant. The corresponding constant must be declared in `Model`'s namespace (`@Const` component).

- `nominal` (optional): a `Float64` nominal value which will be used as an initial value for the parameter. If it is skipped than the default constant value from model will be used.

- `lower` (optional): a `Float64` value that declares the lower bound of the parameter. If skipped than the parameter value will not be limited.

- `upper` (optional): a `Float64` value that declares the upper bound of the parameter. If skipped than the parameter value will not be limited.

- `scale` (optional): `String` which can be `lin`, `log`, `logit`. Using the option user can select the space for parameter optimization. Default value is `lin`.

- `estimate` (optional): a `Boolean` value: `true` or `false` or numerical values `0` or `1` which declares if the parameter should be fitted. `0` or `false` value just states the numerical value but the parameter will not be fitted. Default value is `true`.

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
--- | --- | --- | ---- | ---- | ---
sigma\_K|0.1|1e-6|1e3|log|1
sigma\_P|0.1|1e-6|1e3|log|1
Kp\_K\_D|5.562383e+01|1e-6|1e3|log|1
Kp\_R\_D|5.562383e+01|1e-6|1e3|log|0

Read as `DataFrame` object.

```julia
params = read_parameters("./parameters.csv")
res = fit(p, params)
```

As a result the Platform will be fitted based on all experimental data using three parameters: `sigma_K`, `sigma_P`, `Kp_K_D` in log space.

These operations are equivalent to the following.

```julia
res = fit(
    p,
    [:sigma_K => 0.1, :sigma_P => 0.1, :Kp_K_D => 5.562383e+01];
    parameters_upd = [:Kp_R_D => 5.562383e+01]
    lbounds = [1e-6, 1e-6, 1e-6],
    ubounds = [1e3, 1e3, 1e3],
    scale = [:log, :log, :log]
)
```
