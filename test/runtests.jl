using ChemistryQuantitativeAnalysisUI, ChemistryQuantitativeAnalysis, TypedTables
const CQA = ChemistryQuantitativeAnalysis
const UI = ChemistryQuantitativeAnalysisUI
using Test

repo1 = joinpath(@__DIR__(), "data", "initial_mc_r.batch")
repo2 = joinpath(@__DIR__(), "data", "initial_mc_c.batch")

temp_attr = read_temp_attr(joinpath(@__DIR__(), "..", "attr_templates"))
fig_attr = last(temp_attr[findfirst(x -> first(x) == :fig, temp_attr)])
axis_attr = last(temp_attr[findfirst(x -> first(x) == :axis, temp_attr)])
batch_attr = read_batch_attr(repo2)
initial_mc_c = CQA.read(repo2, Table)
initial_mc_r = CQA.read(repo1, Table)
t1 = Task(() -> begin
    @info "Check the calibration result in $repo1 after saving it within 1 minute"
    UI.run!(initial_mc_r; dir = joinpath(@__DIR__(), "data"), async = false, timeout = 60)
end
)

t2 = Task(() -> begin
    @info "Check the calibration result in $repo2 after saving it within 1 minute"
    UI.run!(repo2; async = true, timeout = 60)
end
)
# wait(schedule(t1))
# wait(schedule(t2))
@testset "ChemistryQuantitativeAnalysisUI.jl" begin
    @test axis_attr[:title](initial_mc_c.calibrator[1]) == "Analyte1"
    @test fig_attr[:size] == (1350, 750)
end
