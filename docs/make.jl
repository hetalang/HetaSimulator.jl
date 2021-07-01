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
        "Basics" => ["basics/intro.md", "basics/platform-based.md", "basics/platform-free.md"],
        "Table formats" => ["table-formats/cond.md", "table-formats/measurement.md"],
        "API" => "api.md"
    ],
)

deploydocs(
    repo = "github.com/hetalang/HetaSimulator.jl.git",
    target = "build",
)
