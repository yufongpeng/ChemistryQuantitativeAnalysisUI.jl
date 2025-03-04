module ChemistryQuantitativeAnalysisUI
using Reexport, GLMakie, GLM, CSV, TypedTables, PlotlyJS, LinearAlgebra, Blink, JSON3
using Gtk4: save_dialog
@reexport using ChemistryQuantitativeAnalysis
export cal_ui!, read_temp_attr, get_batch_attr, read_batch_attr, write_batch_attr

include("attr.jl")
include("calplot.jl")
include("tableplot.jl")

end
