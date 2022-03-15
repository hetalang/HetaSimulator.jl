# ROAD MAP

_Created: 2022-03-02_

## Methods

### I. Types revision

- [ ] `observables` revision: compatibility with DiffEq, interpolation techniques instead of `saveat` approach
- [ ] `Model` revision: import from macros, general-purpose ODE consumption, faster loading
- [ ] `mc` (Monte Carlo) method updates: online-statistics, auto-stop by criterion

### II. Optimization

- [ ] Parameter updates in `Measurement`
- [ ] `loss` method revision: separate from `fit` method
- [ ] `fit` method revision: interface update, another optimization methods, visualization
- [ ] `identify` method: calculation of CI, CB

### III. Visualization

- [ ] Extend plot recipes: compose plots based on tags, split plots horizontally

### IV. Non-ODE simulations

- [ ] `NonODEScenario` implementation: allow simulation and fitting by explicit expressions like in DBSolve

### V. Table formats

- [ ] extend `Measurement` format: more flexible tables, wide-format, macros
- [ ] PETAB compatibility: PETAB standardization, PETAB import

### VI. Additional methods

- [ ] Parallel fitting methods: genetic, semi-parallel approaches
- [ ] Implementation of Global sensitivity analysis (GSA): FAST, eFAST, Sobol
- [ ] Graphical User Interface: Qt, VSCode plugin, web-application
- [ ] Markov Chain Monte Carlo (MCMC)
- [ ] Non-Linear Mixed Effect (NLME)

## Techniques and use cases

- Analysis of dependent fitted parameter
- Validation
- Local sensitivity
- Global sensitivity
- Structural identifiability
- Practical identifiability and predictability
- Optimal experiment development (design)
- Predictive and prognostic biomarker discovery
- Virtual population
- Cloud resources for parallel simulations
- Working examples: dynamic reports, auto-reporting, web applications
