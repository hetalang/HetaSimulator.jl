## bugs

- `parameters` method in Scenario should get the scenario-level parameters but not the full list of constants
- zero time event savings

## features

- Empty object in parameters instead of nothing
- implement Regression sensitivity method
- remove experimental points from legend

- checking units while load_platform
- legend outside of plot
- split plots horizontally
- add loss methods for Condition, Vector{Condition} 
- add CI estimation
- checking `atStart: true`, `atStart: false` inside Events
- read Scenario from Heta
- rename Results => Result

## postponed changes

- `OrderedDict` for storing SimResults
- special approach for analysis of `MCResults`: statistics
- checking Model version
- implement optimization of `mc`: online statistics, auto-stop by criterion
- compose plots based on tags
- examples of extended graphics using plotly, etc.
- https://diffeq.sciml.ai/stable/analysis/global_sensitivity/
