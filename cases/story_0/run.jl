#=
    Example from README.md file
    use heta_update_dev()
=#

using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("$HetaSimulatorDir/cases/story_0", units_check=true, rm_out = false)

# wait for the model compilation...

# get the base Heta model
model = platform.models[:nameless]

# single simulation
results = Scenario(model, (0., 1200.)) |> sim

plotd = plot(results)
# savefig(plotd,"file.png")

# translate to data frame
df = DataFrame(results)
