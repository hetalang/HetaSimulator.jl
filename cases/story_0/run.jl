#=
    Example from README.md file
    use heta_update_dev()
=#

using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("$HetaSimulatorDir/cases/story_0")
# wait for the model compilation...

# get the base Heta model
model = platform.models[:nameless]

# single simulation
results = Scenario(model; tspan = (0., 1200.), parameters=[:k1=>0.1]) |> sim;
plotd = plot(results)
# savefig(plotd,"file.png")

# translate to data frame
df = DataFrame(results)
