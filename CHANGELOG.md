# Change Log

## 0.4.2

- update `show` method for many types
- remove `sim(m::Model)` support
- support of statistics for `mc` method
- `vars` argument in `DataFrame` method for `SimResults`
- `add_scenarios!` method for `Vector{Pair{Symbol, Scenario}}` 

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
