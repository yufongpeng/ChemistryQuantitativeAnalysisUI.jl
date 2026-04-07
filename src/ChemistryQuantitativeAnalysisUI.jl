module ChemistryQuantitativeAnalysisUI
using Reexport, GLMakie, GLM, CSV, TypedTables, PlotlyJS, LinearAlgebra, Blink, JSON3
using Gtk4: save_dialog, open_dialog, ask_dialog
@reexport using ChemistryQuantitativeAnalysis
export read_temp_attr, get_batch_attr, read_batch_attr, write_batch_attr
const CQA = ChemistryQuantitativeAnalysis

include("attr.jl")
include("default.jl")
include("main.jl")
include("utils.jl")
include("validator.jl")

end
