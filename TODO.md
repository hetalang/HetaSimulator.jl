_The rest of ideas and issues are posted in https://github.com/hetalang/heta-discussion/discussions and https://github.com/hetalang/HetaSimulator.jl/issues_

## bugs

- `parameters` method in Scenario should get the scenario-level parameters but not the full list of constants
- wrong get parameters from MCResults, Pair{Symbol, MCResults}, Vector{Pair{Symbol, MCResults}}
- very slow show(::Model)

## fitting

- file storing intermediate results: `current-fitting.heta`
- parameter updates in `Measurements`
- ? storing optimal fitted values inside platform
- ? `Measurements` as an external object like `parameters` for `mc`

## features

- extra columns `tags` in scenario-tables with storage in `Scenario` type
- Additional distribution type for loss function: unified, laplace, BQL
- sim() and mc() are compiled independently
- legend outside of plot
- split plots horizontally
- checking `atStart: true`, `atStart: false` inside Events

## ideas

- remove all LabelledArrays
- Explicit simulations, ExplicitScenario/NonODEScenario ?
- read Scenario from Heta
- add CI estimation
- `OrderedDict` for storing SimResults
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- advanced global sensitivity: https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
