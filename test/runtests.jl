using ChemistryQuantitativeAnalysisUI, ChemistryQuantitativeAnalysis, TypedTables
const CQA = ChemistryQuantitativeAnalysis
using Test
repo1 = joinpath(@__DIR__(), "data", "initial_mc_r.batch")
repo2 = joinpath(@__DIR__(), "data", "initial_mc_c.batch")
initial_mc_r = CQA.read(repo1, Table)
temp_attr = read_temp_attr(joinpath(@__DIR__(), "..", "attr_templates"))
fig_attr = last(temp_attr[findfirst(x -> first(x) == :fig_attr, temp_attr)])
axis_attr = last(temp_attr[findfirst(x -> first(x) == :axis_attr, temp_attr)])
@testset "ChemistryQuantitativeAnalysisUI.jl" begin
    @test axis_attr[:title](initial_mc_r.calibration[1]) == "Analyte1"
    @test fig_attr[:size] == (1350, 750)
    @info "Check the calibration result in $repo1 after saving it within 2 minutes"
    cal_ui!(initial_mc_r; root = repo1, async = false, timeout = 120)
    @info "Check the calibration result in $repo2 after saving it within 2 minutes"
    cal_ui!(repo2; async = true, timeout = 120)
end
