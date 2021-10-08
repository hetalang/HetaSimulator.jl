## bugs

- `parameters` method in Scenario and SimResults should get the scenario-level parameters but not the full list of constants

## features

- `OrderedDict` for storing SimResults
- checking units while load_platform
- better show methods
- legend outside of plot
- split plots horizontally 
- add loss methods for Condition, Vector{Condition} 
- add CI estimation
- checking `atStart: true`, `atStart: false` inside Events
- read Scenario from Heta
- implement Regression sensitivity method

## postponed changes

- special approach for analysis of `MCResults`: statistics
- checking Model version
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
