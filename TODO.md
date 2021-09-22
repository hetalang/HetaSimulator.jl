## bugs

- проверка размерности при load_platform
- 

## features

- метод `get_measurements_as_dataframe()` для `Platform`, `Conditions`, `SimResults`
- метод `save_heta(fit_results)`
- метод `load_parameters()` + новая структура параметров в `fit` + scale
- переименовать `Condition` в `Scenario`
- удалить поддерку методов для `Model`

- более информативные show для объектов
- примеры в документации с использованием plotly и вариантов красивых графиков
- легенда не помещается на рисунке
- ? доп проверка на этапе read_conditions
+ множественные графики не помещаются на одну панель
- компоновка графиков по желанию пользователя. ? Tags

- add fit methods for Model, Condition, Vector{Condition} 
- add CI
- checking `atStart: true`, `atStart: false` inside Events
- 

## postponed changes

- checking Model version
- 