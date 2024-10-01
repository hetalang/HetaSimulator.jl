# Change Log

## 0.7.1

- `spaceFilter` fixed
- docker qsp-platforms-builder after TagBot

## 0.7.0

- heta-compiler updated to 0.9.0
- changes in `load_platform`: add `spaceFilter`
- docker qsp-platforms-builder added to github/actions
- GSA Tutorial added to docs

## 0.6.2

- added aarch64 macos support
- error if arch/os is not supported by heta-compiler

## 0.6.1

- heta-compiler updated to 0.8.7

## 0.6.0

- NodeJS dep removed. heta exe depoyed as artifact without node intallation
- fitting issue with additional parameters fixed

## 0.5.2

- heta-compiler updated to v0.8.4

## 0.5.1

- statics and constants usage in events fix 
- ArrayPartition introduced to access statics and constants  

## 0.5.0

- heta-compiler updated to v0.8.1
- saving function optimized to solve StackOverflow problem and reduce saving time
- DiffEqBase and RecursiveArrayTools dependencies replaced with SciMLBase
- Julia support limited to 1.9-latest
- support latest CSV.jl version
- support latest Sundials.jl version
- piecewise function support added
- order of constants and statics changed

## 0.4.15

- update heta-compiler for v0.7.4
- autoremove whitespaces in table headers: `scenario`, `measurements`, `parameters`
- extend heta cli connector: `heta`, `heta_help`, `heta_init`, `heta`
- Int parameters support in Scenario
- mass_matrix support in Model type
- allow additional parameters not present in Model

## 0.4.14

- support for heta-compiler v0.7.1
- Sundials ver restricted <= 4.19.3
- Float64 for tspan and saveat
- saveat ranges support in Scenario tables
- constants, records and switchers renaming
- Documenter v1 support

## 0.4.13

- support for Julia 1.9
- support for heta-compiler v0.6.16
- safetycopy for remake(prob)
- unite df with different observables
- ci_types added to EnsembleSummary
- promote_type u0

## 0.4.12

- support of Julia 1.8
- support heta-compiler v0.6.15
- fix compatibility of dependences
- selection of Ensemble summary
- new format of `__p__` vector

## 0.4.11

- constant id check in `mc`
- `mc!` method to racalculate MCResults
- move back `saveat` into `Scenario`

## 0.4.10

- fix EMPTY_PROBLEM bug

## 0.4.9

- fix memory issues for `mc`
- support `plot` for `EnsembleSummary` pairs
- fix `EnsembleSummary` for `MCResults`
- `add_parameters` in DataFrame method
- experimental: `tags[]` and `group` property in `Scenario` for combining Simulation results

## 0.4.8

- `estimator` method to return estimator function
- `fit` progress display
- `:lin` and `:direct` are synonyms
- fix `NaNMath` problem 2

## 0.4.7

- fix `NaNMath` bug
- heta-compiler v0.6.11

## 0.4.5 - deprecated

- add support for `mc(..., params::DataFrame, ...)` where the first argument is vector or platform
- use `NaNMath` functions inside model
- main version of compiler is fixed to __0.6.10__
- `output` and `reduce` func added to `mc`
- fix Results to `DataFrame` conversion
- move `saveat` from `Scenario` to `sim` and `mc`

## 0.4.4

- remove manifest file
- units checking support

## 0.4.3 - skipped

## 0.4.2

- add global sensitivity for `MCResult`: `gsa`
- add `save_as_heta` method
- rename `Results` to `Result`
- fix bug to allow params in loss func
- remove fake run inside `load_platform`
- update `show` method for many types
- remove `sim(m::Model)` support
- `vars` argument in `DataFrame` method for `SimResults`
- `add_scenarios!` method for `Vector{Pair{Symbol, Scenario}}` 
- `OrderedDict` in `Platform`
- update `plot` style
- fix bug with single `saveat`
- fix bugs in saving callback

## 0.4.1

- Rename `Condition` => `Scenario`
- minor fixes to rewrite saved values in SimResults
- plot layout changes
- distribution type :lognormal
- `read_parameters` method
- `save_optim` method

## 0.4.0

- autotests added
- API refs and quick start
- progress bar in `mc` method
- fix "task modification" bug 
- rename `Cond` to `Condition`
- reset_dt! fixed for event at zero

## 0.3.0 - first public

- `sim`, `fit`, `mc` methods
- reading Heta platforms
- importing conditions and measurements tables from xlsx/csv
- parallel MonteCarlo simulations
