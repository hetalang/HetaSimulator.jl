## bugs

- `parameters` method in Scenario should get the scenario-level parameters but not the full list of constants
- get parameters from MCResults, Pair{Symbol, MCResults}, Vector{Pair{Symbol, MCResults}}

## features

- Empty object in parameters instead of nothing
- legend: display experimental points on line
- check conversion from SimResults, MCResults to DataFrame: where is constants?
- legend outside of plot
- split plots horizontally
- checking `atStart: true`, `atStart: false` inside Events
- rename Results => Result
- allow using both saveat and tspan

## postponed changes

- extended chain syntax
- read Scenario from Heta
- add CI estimation
- add loss methods for Condition, Vector{Condition}
- checking units while load_platform
- `OrderedDict` for storing SimResults
- checking Model version
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- another global sensitivity: https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
