using DataFrames

platform = load_platform(joinpath(@__DIR__, "examples", "single_comp"); ir_format=:julia)
model = models(platform)[:nameless]

@testset "Constructor and result tables" begin
    labeled = Scenario(model, (0., 10.); 
        group=:treatment, tags=[:validation, :high_dose])
    @test labeled.group === :treatment
    @test labeled.tags == [:validation, :high_dose]

    labeled_df = DataFrame(sim(labeled))
    # has coulmns
    @test "group" in names(labeled_df)
    @test "tags.validation" in names(labeled_df)
    @test "tags.high_dose" in names(labeled_df)
    @test labeled_df.group == fill(:treatment, nrow(labeled_df))
    @test labeled_df[!,"tags.validation"] == fill(true, nrow(labeled_df))
    @test labeled_df[!,"tags.high_dose"] == fill(true, nrow(labeled_df))
end
