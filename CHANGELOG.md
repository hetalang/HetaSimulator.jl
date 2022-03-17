# Change Log

## 0.4.8

- `estimator` method to return estimator function
- `fit` progress display
- `:lin` and `:direct` are synonyms

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
