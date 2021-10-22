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
        "Home" => "index.md", # readme
        "Basics" => [ # background, discussion
            "basics/overview.md",
            "table-formats/scenario.md",
            "table-formats/measurement.md",
            "table-formats/parameters.md"
        ],
        "Tutorial" => [ # methods
            "tutorial/intro.md",
            "tutorial/sim.md",
            "tutorial/mc.md",
            "tutorial/fit.md",
        ],
        "API" => "api.md"
    ],
)

deploydocs(
    repo = "github.com/hetalang/HetaSimulator.jl.git",
    target = "build",
)
