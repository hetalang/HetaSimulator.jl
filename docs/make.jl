using Documenter, HetaSimulator

makedocs(sitename="HetaSimulator Docs",
  modules = [HetaSimulator],
      pages = [
          "Home"=> "index.md",
          "API" => "api.md"
      ],
  )

deploydocs(
    repo = "github.com/hetalang/HetaSimulator.jl.git",
    target = "build",
)