# Parameters tables

Parameters tables are CSV or XLSX files which store settings for parameter identification problems.
The content of the table can be loaded into Julia environment as a `DataFrame` to be used inside `fit` method.

## Format

The first row is intended for headers which clarify the columns meaning. The sequence of columns is not important.

- `id` : a `String` representing unique identifier of constant. The corresponding constant must be declared in `Model`'s namespace (`@Const` component).

- `value` (optional): a `Float64` nominal value which will be used as an initial value for the parameter. If the value is skipped than the default value from model will be used.

- `lower` (optional): a `Float64` value that declares the lower bound of the parameter. If skipped than the parameter value will not be limited.

- `upper` (optional): a `Float64` value that declares the upper bound of the parameter. If skipped than the parameter value will not be limited.

- `scale` (optional): `String` which can be `direct`, `log`, `logit`. Using the option user can select the space for parameter optimization. Default value is `direct`.

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

id | value | lower | upper | scale | estimate
--- | --- | --- | ---- | ---- | ---
sigma\_K|0.1|1e-6|1e3|log|1
sigma\_P|0.1|1e-6|1e3|log|1
Kp\_K\_D|5.562383e+01|1e-6|1e3|log|1
Kp\_R\_D|5.562383e+01|1e-6|1e3|log|0

Read as `DataFrame` object.

```julia
params = read_conditions("./parameters.csv")
res = fit(p, params)
```

As a result the Platform will be fitted based on all experimental data using three parameters: `sigma_K`, `sigma_P`, `Kp_K_D` in log space.

These operations are equivalent to the following.

```julia
params = [
    :sigma_K = [:value => 0.1, :lower => 1e-6, :upper => 1e3, :scale => :log, :estimate => true],
    :sigma_P = [:value => 0.1, :lower => 1e-6, :upper => 1e3, :scale => :log, :estimate => true],
    :Kp_K_D = [:value => 5.562383e+01, :lower => 1e-6, :upper => 1e3, :scale => :log, :estimate => true],
    :Kp_R_D = [:value => 5.562383e+01, :lower => 1e-6, :upper => 1e3, :scale => :log, :estimate => false]
]
res = fit(p, params)
```
