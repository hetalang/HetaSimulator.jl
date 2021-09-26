# Measurements tables

Measurements tables are CSV or XLSX files which store `Measurement` objects in tabular format.
The content of the table can be loaded into Julia environment as a `DataFrame` to be included into `Platform` object.

## Format

The structure of tables corresponds to `Measurements` properties.
The first row is intended for headers which clarify the columns meaning. The sequence of columns is not important.

- `scenario` : a `String` value representing identifier of `Scenario`.
- `t` : a `Float64` value equal to time point of measured value
- `measurement` : a `Float64` measured value
- `scope` (optional): a `String` value which states a scope of simulation to be compared with measurements. Default value is `ode_`
- `prob.<id>` : a set of options to characterize the probability distribution. The supported `id`s depend on distribution type. For `normal` and `lognormal` distributions the available headers are:
    - `prob.type` (optional) : a `String` declaring probability type. `normal` is default.
    - `prob.mean` : `Float64` value or `String` representing `@Const` or `@Record` id in model. The value represents parameter mean in normal distribution.
    - `prob.sigma` : `Float64` value or `String` representing `@Const` or `@Record` id in model. The value represents parameter sigma (standard deviation) in normal distribution.

Currently two base probability types are available: `normal`, `lognormal`. This distributions can be used for creating different types of error models.

### prob.type: normal

Each row in the table will be transformed into a component of log-likelihood function $-2ln(L)$.

```math
\Lambda = \sum_i \left( ln(<prob.sigma>_i^2) + \frac{(<prob.mean>_i - <measurement>_i)^2}{<prob.sigma>_i^2}\right)
```

### prob.type: lognormal

Each row in the table will be transformed into a component of log-likelihood function $-2ln(L)$.

```math
\Lambda = \sum_i \left( ln(<prob.sigma>_i^2) + \frac{(ln(<prob.mean>_i) - ln(<measurement>_i))^2}{<prob.sigma>_i^2}\right)
```

## Loading to Platform

Measurement table can be loaded into Julia environment as a `DataFrame` using `HetaSimulator.read_measurements` method. This method reads the file, checks the content and formats the data to be used inside Platform object.

```julia
measurements = read_measurements("measurements.csv")

32×7 DataFrame
 Row │ t        measurement  scope   prob.mean  prob.sigma  scenario  prob.type 
     │ Float64  Float64      Symbol  String     Float64     Symbol     Symbol    
─────┼───────────────────────────────────────────────────────────────────────────
   1 │     2.0     8.46154   ode_    a                1.0   dataone    normal
   2 │     4.0     7.33333   ode_    a                1.2   dataone    normal
   3 │     6.0     6.47059   ode_    a                2.2   dataone    normal
  ⋮  │    ⋮          ⋮         ⋮         ⋮          ⋮           ⋮          ⋮
```

The data frame can be loaded into platform using the `HetaSimulator.add_measurements!` method.

```julia
add_measurements!(platform, measurements)
```

## Example

Loading file measurements.csv with the following content.

t | measurement | scope | prob.mean | prob.sigma | scenario
---|---|---|---|---|---
2 | 8.461539334 | ode_ | a | 1 | dataone
4 | 7.333333812 | ode_ | a | 1.2 | dataone
6 | 6.470591567 | ode_ | a | 2.2 | dataone

Read as `DataFrame` object.

```julia
measurements = read_measurements("./measurements.csv")
```

Add all measurements to Platform

```julia
add_measurements!(platform, measurements)
```

As a result the Platform will contain three measurements.

These operations are equivalent of manually created `Measurement` objects.

```julia
# dataone = Scenario(...)

m1 = NormalMeasurementPoint(2, 8.461539334, :ode, :a, 1)
m2 = NormalMeasurementPoint(4, 7.333333812, :ode, :a, 1.2)
m3 = NormalMeasurementPoint(6, 6.470591567, :ode, :a, 2.2)

push!(dataone.measurements, m1)
push!(dataone.measurements, m2)
push!(dataone.measurements, m3)
```
