using ChemistryQuantitativeAnalysisUI, ChemistryQuantitativeAnalysis, TypedTables
const CQA = ChemistryQuantitativeAnalysis

repo1 = joinpath(@__DIR__(), "data", "initial_mc_r.batch")
repo2 = joinpath(@__DIR__(), "data", "initial_mc_c.batch")
initial_mc_r = CQA.read(repo1, Table)

@info "Check the calibration result in $repo1 after saving it within 2 minutes"
cal_ui!(initial_mc_r; root = repo1, async = false, timeout = 120)
@info "Check the calibration result in $repo2 after saving it within 2 minutes"
cal_ui!(repo2; async = true, timeout = 120)