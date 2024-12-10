using Documenter, HetaSimulator

makedocs(
    sitename = "HetaSimulator.jl",
    authors = "Ivan Borisov, Evgeny Metelkin",
    modules = [HetaSimulator],
    format = Documenter.HTML(
        analytics = "UA-149749027-1",
        #assets = ["assets/favicon.ico"],
        canonical="https://hetalang.github.io/HetaSimulator.jl/stable/"
    ),
    pages = [
        "Home" => "index.md", # readme
        "Basics" => [ # background, discussion
            "basics/overview.md",
            "basics/distributed.md",
            "table-formats/scenario.md",
            "table-formats/measurement.md",
            "table-formats/parameters.md",
            "basics/solvers.md"
        ],
        "Tutorial" => [ # methods
            "tutorial/intro.md",
            "tutorial/sim.md",
            "tutorial/mc.md",
            "tutorial/fit.md",
            "tutorial/gsa.md",
            "tutorial/plots.md"
        ],
        "API" => "api.md"
    ],
)

deploydocs(repo = "github.com/hetalang/HetaSimulator.jl.git")
