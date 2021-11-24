_The rest of ideas and issues are posted in https://github.com/hetalang/heta-discussion/discussions and https://github.com/hetalang/HetaSimulator.jl/issues_

## bugs

- `parameters` method in Scenario should get the scenario-level parameters but not the full list of constants
- wrong get parameters from MCResults, Pair{Symbol, MCResults}, Vector{Pair{Symbol, MCResults}}
- ? slow show method for Model
- 

## features

- allow using both saveat and tspan, move tspan to sim
- remove unnecessary rules from events
- legend outside of plot
- split plots horizontally
- checking `atStart: true`, `atStart: false` inside Events
- rename Results => Result
- add loss methods for Condition, Vector{Condition}

## ideas

- extended chain syntax
- read Scenario from Heta
- add CI estimation
- checking units while load_platform
- `OrderedDict` for storing SimResults
- checking Model version
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- another global sensitivity: https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
