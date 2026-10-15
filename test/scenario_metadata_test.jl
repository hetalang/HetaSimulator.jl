using DataFrames

platform = load_platform(joinpath(@__DIR__, "examples", "single_comp"); ir_format=:julia)
model = models(platform)[:nameless]

@testset "Single simulation metadata" begin
    labeled = Scenario(model, (0., 10.); saveat=[0., 10.],
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

@testset "Monte-Carlo metadata" begin
    labeled_1 = Scenario(model, (0., 10.); saveat=[0., 10.],
        group=:treatment, tags=[:validation, :high_dose])
    labeled_2 = Scenario(model, (0., 10.); saveat=[0., 10.],
        group=:placebo, tags=[:validation, :no_dose])
    variation = [:k1 => [0.01, 0.02]]
    result = mc([labeled_1, labeled_2], variation, 2)
    df = DataFrame(result)
    @test "group" in names(df)
    @test "tags.validation" in names(df)
    @test "tags.high_dose" in names(df)
    @test "tags.no_dose" in names(df)
    gdf = groupby(df, :group)
    df_placebo = gdf[(:placebo,)]
    df_treatment = gdf[(:treatment,)]
    @test df_treatment[!,"tags.high_dose"] == fill(true, nrow(df_treatment))
    @test df_placebo[!,"tags.no_dose"] == fill(true, nrow(df_placebo))
end
