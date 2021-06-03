using HetaSimulator, Plots

# set the absolute or relative path to the project directory
platform = load_platform("./my_project") # wait for the model compilation...
platform = load_platform("./cases/story_0")

# get the base Heta model
model = platform.models[:nameless]

# single simulation
results = sim(model; tspan = (0., 1200.))
plotd = plot(results)
savefig(plotd,"file.png")

# translate to data frame
df = DataFrame(results)
