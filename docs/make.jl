using Documenter, HetaSimulator

makedocs(
    sitename = "HetaSimulator Docs",
    authors = "Ivan Borisov, Evgeny Metelkin",
    modules = [HetaSimulator],
    format = Documenter.HTML(
        analytics = "UA-149749027-1",
        #assets = ["assets/favicon.ico"],
        canonical="https://hetalang.github.io/HetaSimulator.jl/dev/"
    ),
    pages = [
        "Home" => "index.md",
        "Basics" => [
            "basics/overview.md",
            "basics/design.md",
            "table-formats/condition.md",
            "table-formats/measurement.md"
        ],
        "Methods" => ["methods/sim.md"],
        "API" => "api.md"
    ],
)

deploydocs(
    repo = "github.com/hetalang/HetaSimulator.jl.git",
    target = "build",
)
