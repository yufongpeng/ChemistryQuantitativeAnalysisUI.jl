macro q(ex...)
    return string(ex...)
end

macro jl(ex)
    return ex 
end

"""
    TEMP_ATTR = [
        :acc_attr => Dict{Symbol, Any}(:lloq_multiplier => 4//3, :dev_acc => 0.15),
        :axis_attr => Dict{Symbol, Any}(
            :title => cal -> string(first(cal.analyte)), 
            :xlabel => "Concentration (nM)", 
            :ylabel => "Abundance", 
            :titlesize => 20
        ), 
        :cells_attr => Dict{Symbol, Any}(
            :height => 24, 
            :font => attr(size = 12), 
            :line_color => "darkgreen", 
            :align => :right, 
            :fill_color => ["honeydew", "lightpink", "darkseagreen"], 
            :subheader_color => "rgb(235, 193, 238)", 
            :sigdigits => [4, 4, 4, 4]
        ), 
        :data_attr => Dict{Symbol, Any}(
            :sigdigits => [4, 4, 4, 4],
            :digits => [nothing, nothing, nothing, nothing]
        ), 
        :fig_attr => Dict{Symbol, Any}(:size => (1350, 750)), 
        :header_attr => Dict{Symbol, Any}(
            :height => 24, 
            :font => attr(size = 12, color = "white"), 
            :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], 
            :line_color => "darkgreen", 
            :fill_color => "limegreen", 
            :align => "center"
        ), 
        :layout_attr => Dict{Symbol, Any}(
            :title => cal -> string(first(cal.analyte)), 
            :width => 720
        ), 
        :line_attr => Dict{Symbol, Any}(:color => :chartreuse),
        :scatter_attr => Dict{Symbol, Any}(
            :color => [:blue, :red], 
            :inspector_label => cal -> (self, i, p) -> string("id: ", cal.table.id[i], "\nlevel: ", cal.table.level[i], "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
        )
]

Built-in attributes templates collection.

* `acc_attr`: definition of accuracy outliers.
    * `dev_acc`: allowed deviation of accuracy.
    * `lloq_multiplier`: multiplier of `dev_acc` for LLOQ level.
* `data_attr`: digits settings for showing value in main GUI or exporting data. They should be 4-element vectors representing formula, LLOQ, ULOQ and R².
    * `sigdigits`: number of siginificant digits.
    * `digits`: digits after or befor decimal.  
* `axis_attr`: attributes of `Axis`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `fig_attr`: attributes of `Figure`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `line_attr`: attributes of `Lines`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `scatter_attr`: attributes of `Scatter`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/). Note that a single value or a 2-element vector is valid. The latter represent values for selected (first) and unselected (second) points.
* `header_attr`: attributes of header of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/). There sre addtional attributes:
    * `subheader_color`: the color of subheader separating calibration points and sample values of each analyes.
    * `sigdigits`: number of siginificant digits.
    * `digits`: digits after or befor decimal.  
* `cells_attr`: attributes of cells of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/)
* `header_attr`: attributes of header of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/)
* `layout_attr`: attributes of `Layout`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/)

In template files, julia expression can be wrapped as `"@jl julia_expression"`, and string in the expression has to be chabged to `@q string...`. Reserved strings can be build from the corresponding characters. 
"""
const TEMP_ATTR = [
    :acc_attr => Dict{Symbol, Any}(:lloq_multiplier => 4//3, :dev_acc => 0.15),
    :axis_attr => Dict{Symbol, Any}(
        :title => cal -> string(first(cal.analyte)), 
        :xlabel => "Concentration (nM)", 
        :ylabel => "Abundance", 
        :titlesize => 20
    ), 
    :cells_attr => Dict{Symbol, Any}(
        :height => 24, 
        :font => attr(size = 12), 
        :line_color => "darkgreen", 
        :align => :right, 
        :fill_color => ["honeydew", "lightpink", "darkseagreen"], 
        :subheader_color => "rgb(235, 193, 238)", 
        :sigdigits => [4, 4, 4, 4]
    ), 
    :data_attr => Dict{Symbol, Any}(
        :sigdigits => [4, 4, 4, 4],
        :sigdigits => [nothing, nothing, nothing, nothing]
    ), 
    :fig_attr => Dict{Symbol, Any}(:size => (1350, 750)), 
    :header_attr => Dict{Symbol, Any}(
        :height => 24, 
        :font => attr(size = 12, color = "white"), 
        :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], 
        :line_color => "darkgreen", 
        :fill_color => "limegreen", 
        :align => "center"
    ), 
    :layout_attr => Dict{Symbol, Any}(
        :title => cal -> string(first(cal.analyte)), 
        :width => 720
    ), 
    :line_attr => Dict{Symbol, Any}(:color => :chartreuse),
    :scatter_attr => Dict{Symbol, Any}(
        :color => [:blue, :red], 
        :inspector_label => cal -> (self, i, p) -> string("id: ", cal.table.id[i], "\nlevel: ", cal.table.level[i], "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
    )
]

"""
    read_temp_attr(input::AbstractString)

Read attributes template. In template files, julia expression can be wrapped as `"@jl julia_expression"`, and string in the expression has to be chabged to `@q string...`. Reserved strings can be build from the corresponding characters. 
"""
function read_temp_attr(input::AbstractString)
    ks = ["acc_attr", "axis_attr", "cells_attr", "data_attr", "fig_attr", "header_attr", "layout_attr", "line_attr", "scatter_attr"]
    fs = [open(joinpath(input, string(k, ".json")), "r") for k in ks]
    attrs = [Symbol(k) => eval_attr_fn!(JSON3.read(f, Dict{Symbol, Any})) for (k, f) in zip(ks, fs)]
    close.(fs)
    attrs 
end

"""
    read_batch_attr(input::AbstractString)

Read attributes in a bacth. Juia expression is not allowed. 

```json
{
    "attr.1": 1,
    "attr.2": 2
}
````
will become a Tuple (1, 2) for `:attr`. 

Nested json objects will become `PlotlyJS.PlotlyAttribute`.
"""
function read_batch_attr(input::AbstractString)
    endswith(input, ".batch") || throw(ArgumentError("The input is not a batch directory."))
    dir = joinpath(input, "calibration")
    ks = ["acc_attr", "axis_attr", "cells_attr", "data_attr", "fig_attr", "header_attr", "layout_attr", "line_attr", "scatter_attr"]
    attrs = Dict([Symbol(k) => Dict{Symbol, Any}[] for k in ks]...)
    for d in readdir(dir)
        if "attr" in readdir(joinpath(dir, d))
            da = readdir(joinpath(dir, d, "attr"))
            for (k, v) in attrs 
                f = string(k, ".json") in da ? open(joinpath(dir, d, "attr", string(k, ".json")), "r") : IOBuffer("{}")
                push!(v, eval_attr_fn!(JSON3.read(f, Dict{Symbol, Any})))
                close(f)
            end
        else
            for v in values(attrs)
                push!(v, Dict{Symbol, Any}())
            end
        end
    end
    attrs
end

function eval_attr_fn!(attrs)
    # create tuple
    ks = keys(attrs)
    sk = @. split(string(ks), ".")
    kmap = Dict{Symbol, Any}()
    for (vk, k) in zip(sk, ks) 
        if length(vk) == 1 
            push!(kmap, k => k)
        else
            push!(get!(kmap, Symbol(first(vk)), Symbol[]), k)
        end
    end
    for (k, v) in kmap
        if v isa Vector
            sort!(v)
            attrs[k] = ntuple(i -> attrs[v[i]], length(v))

        end
    end
    for (k, v) in attrs 
        if v isa AbstractString && startswith(v, "@jl ")
            attrs[k] = eval(Meta.parse(v))
        elseif v isa Dict 
            attrs[k] = attr(; (Symbol(k) => v for (k, v) in v)...)
        end
    end
    attrs
end

# generate attr for each calibration curve
"""
    get_batch_attr(batch::Batch, temp_attrs = TEMP_ATTR)

Create valid attributes object for a batch from a collection attributes templates.
"""
function get_batch_attr(batch::Batch, temp_attrs = TEMP_ATTR)
    Dict{Symbol, Any}([attr => map_attrs(dict, batch.calibration) for (attr, dict) in temp_attrs]...)
end

function map_attrs(dict, cal)
    [Dict{Symbol, Any}((k => (v isa Function ? v(c) : v) for (k, v) in dict)...) for c in cal]
end

function add_default_attrs!(attrs, batch::Batch)
    for (a, v) in attrs
        for (dict, cal) in zip(v, batch.calibration)
            if a == :acc_attr
                get!(dict, :lloq_multiplier, 4//3)
                get!(dict, :dev_acc, 0.15)
            elseif a == :fig_attr
                get!(dict, :size, (1350, 750))
            elseif a == :axis_attr 
                get!(dict, :title, string(first(cal.analyte)))
                get!(dict, :xlabel, "Concentration (nM)")
                get!(dict, :ylabel, "Abundance")
                get!(dict, :titlesize, 20)
            elseif a == :scatter_attr 
                get!(dict, :color, [:blue, :red])
                get!(dict, :inspector_label, (self, i, p) -> string("id: ", cal.table.id[i], 
                    "\nlevel: ", cal.table.level[i], 
                    "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
                )
            elseif a == :line_attr 
                get!(dict, :color, :chartreuse)
            elseif a == :layout_attr 
                get!(dict, :title, string(first(cal.analyte)))
                get!(dict, :width, 720)
            elseif a == :header_attr 
                get!(dict, :height, 24)
                get!(dict, :font, attr(size = 12, color = "white"))
                get!(dict, :values, ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"])
                get!(dict, :line_color, "darkgreen")
                get!(dict, :fill_color, "limegreen")
                get!(dict, :align, "center")
            elseif a == :cells_attr 
                get!(dict, :height, 24)
                get!(dict, :font, attr(size = 12))
                get!(dict, :line_color, "darkgreen")
                get!(dict, :align, "right")
                get!(dict, :fill_color, ["honeydew", "lightpink", "darkseagreen"])
                get!(dict, :subheader_color, "rgb(235, 193, 238)")
                default_digits!(dict)
            elseif a == :data_attr
                default_digits!(dict)
            end
        end
    end
    attrs
end

"""
    write_batch_attr(output::AbstractString, attrs)

Write attributes to a batch. 
"""
function write_batch_attr(output::AbstractString, attrs)
    endswith(output, ".batch") || throw(ArgumentError("The output is not a batch directory."))
    in("calibration", readdir(output)) || throw(ArgumentError("The output was not initialized for calibration. Read it and apply `init_calibration!` first."))
    dir = joinpath(output, "calibration")
    for (i, d) in enumerate(readdir(dir))
        mkpath(joinpath(dir, d, "attr"))
        for (k, v) in attrs
            dict = v[i]
            id = findall(x -> x isa Tuple, dict)
            if !isempty(id)
                dict = deepcopy(dict)
                for kd in id 
                    vd = dict[kd]
                    delete!(dict, kd)
                    for (ix, e) in enumerate(vd)
                        push!(dict, Symbol(string(kd, ".", ix)) => e)
                    end
                end
            end
            id = findall(x -> x isa Function, dict)
            if !isempty(id)
                dict = deepcopy(dict)
                for kd in id 
                    delete!(dict, kd)
                end
            end
            open(joinpath(dir, d, "attr", string(k, ".json")), "w") do io
                JSON3.pretty(io, dict)
            end
        end
    end
end

function default_digits!(dict)
    dict[:sigdigits] = convert(Vector{Any}, get(dict, :sigdigits, [4, 4, 4, 4]))
    dict[:digits]  = convert(Vector{Any}, get(dict, :digits, [nothing, nothing, nothing, nothing]))
    for (i, (s, d)) in enumerate(zip(dict[:sigdigits], dict[:digits]))
        if isnothing(d)
            dict[:sigdigits][i] = isnothing(s) ? 4 : s
        elseif !isnothing(s) && !isnothing(d)
            dict[:sigdigits][i] = nothing
        end
    end 
    dict
end