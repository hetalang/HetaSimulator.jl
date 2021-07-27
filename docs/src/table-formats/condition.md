# Conditions tables

Conditions tables are CSV or XLSX files which store `Condition` objects in tabular format.
The content of the table can be loaded into Julia environment as a `DataFrame` to be included into `Platform` object.

## Format

The structure of the tables corresponds to `Condition` properties.
The first row is intended for headers which clarify the columns meaning. The sequence of columns is not important.

- `id` : a `String` representing unique identifier of `Condition` if you load into `Platform` object. The string should be unique within the condition set and must follow the common identifier rules: no blank spaces, no digit at the first symbol, etc.

- `model` : a `String` identifier of model which will be used for simulations. The default value is `nameless`.

- `parameters.<id>` (optional) : a `Float64` value which updates and fixes the value of model's `Const` with the corresponding id. Missing value does not updates the parameter's value and is ignored.

- `saveat[]` (* optional) : a set of `Float64` values separated by semicolons. The values states the time points for simulated output.

- `tspan` (* optional) : a `Float64` value which are maximal simulation time point. BTW the initial time point is always 0.

- `observables[]` (optional) : a set of `String` separated by semicolon. They state the model records that will be saved as simulation results. If not set the default observables will be used (`output: true` property in Heta notation).

- `events_active.<id>` (optional) : a `Bool` value which updates turns on and off events in model. The `id` is switcher identifier in the Heta. If it is not set the `switcher.active` state from Heta model will be used.

- `events_save.<id>` (optional, experimental) : a pair of `Bool` values divided by semicolon. This value set if it is required to save the output value before and after the event. If not set both: before and after values will be saved.

_* `saveat[]` or `tspan` must be set for the particular `Condition`. If you set both only `saveat[]` will be used._

## Loading to Platform

Condition table can be loaded into Julia environment as a `DataFrame` using `HetaSimulator.read_conditions` method. This method reads the file, checks the content and formats the data to be used inside Platform object.

```julia
conditions_csv = read_conditions("./conditions.csv")

4×7 DataFrame
 Row │ id         parameters.k1  parameters.k2  parameters.k3  saveat[]           tspan      observables[] 
     │ Symbol     Float64?       Float64?       Float64?       String?            Float64?   String?       
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ dataone     missing               0.001           0.02  0;12;24;48;72;120      150.0  missing       
   2 │ withdata2         0.001     missing         missing     0;12;24;48;72;120  missing    missing       
   3 │ three             0.001           0.1       missing     missing                250.0  missing       
```

The data frame can be loaded into platform using the `HetaSimulator.add_conditions!` method.

```julia
add_conditions!(platform, conditions_csv)

conditions(platform)
Dict{Symbol, Condition} with 4 entries:
  :three     => Condition{...}
  :withdata2 => Condition{...} 
  :dataone   => Condition{...}
```

## Example

Loading file __conditions.csv__ with the following content.

id | model | parameters.k1 | parameters.k2 | parameters.k3 | saveat[] | tspan | observables[] | events_active.sw1 | events_active.sw2 | events_save.sw1
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
cond1 | |  | 0.001 | 0.02 | 0;12;24;48;72;120;150 | | | true | false | true;false
cond2 | nameless | 0.001 |  |  | |  1000 | | | true |
cond3 | another_model | | 0.001  |  | 0;12;24;48;72;120 |  | | false |

Read as `DataFrame` object.

```julia
conditions = read_conditions("./conditions.csv")
```

Add all conditions to Platform

```julia
add_conditions!(platform, conditions)
```

As a result the Platform will contain three conditions: cond1, cond2, cond3.

These operations are equivalent of manually created `Condition` objects.

```julia
cond1 = HetaSimulator.Condition(
  platform.models[:nameless];
  parameters = [:k2=>0.001, :k3=>0.02],
  saveat = [0, 12, 24, 48, 72, 120, 150],
  events_active = [:sw1=>true, :sw2=>false],
  events_save = [:sw1=>(true,false)]
)
push!(platform.conditions, :cond1=>cond1)

cond2 = HetaSimulator.Condition(
  platform.models[:nameless];
  parameters = [:k1=>0.001],
  tspan = (0., 1000.),
  events_active = [:sw2=>true]
)
push!(platform.conditions, :cond2=>cond2)

cond3 = HetaSimulator.Condition(
  platform.models[:another_model];
  parameters = [:k2=>0.001],
  saveat = [0, 12, 24, 48, 72, 120],
  events_active = [:sw1=>false]
)
push!(platform.conditions, :cond3=>cond3)

```
