_The rest of ideas and issues are posted in https://github.com/hetalang/heta-discussion/discussions and https://github.com/hetalang/HetaSimulator.jl/issues_

## bugs

- `parameters` method in Scenario should get the scenario-level parameters but not the full list of constants
- wrong get parameters from MCResults, Pair{Symbol, MCResults}, Vector{Pair{Symbol, MCResults}}
- very slow show(::Model)

## features

- Additional distribution type for loss function: unified, laplace, BQL
- parameter updates in `Measurements`
- checking units when `load_platform`
- sim() and mc() are compiled independently
- legend outside of plot
- split plots horizontally
- checking `atStart: true`, `atStart: false` inside Events
- add loss methods for `Condition`, `Vector{Condition}`
- extended chain syntax

## ideas

- Explicit simulations, ExplicitScenario/NonODEScenario ?
- read Scenario from Heta
- add CI estimation
- `OrderedDict` for storing SimResults
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- another global sensitivity: https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
