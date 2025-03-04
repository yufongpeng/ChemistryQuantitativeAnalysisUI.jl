using ChemistryQuantitativeAnalysisUI
using Test

temp_attr = read_temp_attr(joinpath(@__DIR__(), "..", "attr_templates"))
fig_attr = last(temp_attr[findfirst(x -> first(x) == :fig_attr, temp_attr)])
axis_attr = last(temp_attr[findfirst(x -> first(x) == :axis_attr, temp_attr)])
@testset "ChemistryQuantitativeAnalysisUI.jl" begin
    @test axis_attr[:title](initial_mc_r.calibration[1]) == "Analyte1"
    @test fig_attr[:size] == (1350, 750)
end
