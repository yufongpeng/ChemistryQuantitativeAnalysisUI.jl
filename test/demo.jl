using ChemistryQuantitativeAnalysisUI, ChemistryQuantitativeAnalysis, TypedTables
const CQA = ChemistryQuantitativeAnalysis
const UI = ChemistryQuantitativeAnalysisUI

repo1 = joinpath(@__DIR__(), "data", "initial_mc_r.batch")
repo2 = joinpath(@__DIR__(), "data", "initial_mc_c.batch")
initial_mc_r = CQA.read(repo1, Table)

@info "Check the calibration result in $repo1 after saving it within 2 minutes"
UI.run!(initial_mc_r; dir = joinpath(@__DIR__(), "data"), async = false, timeout = 120)
@info "Check the calibration result in $repo2 after saving it within 2 minutes"
UI.run!(repo2; async = true, timeout = 120)