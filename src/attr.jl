macro q(ex...)
    return string(ex...)
end

macro jl(ex)
    return ex 
end

"""
    TEMP_ATTR = [
        :acc => Dict{Symbol, Any}(:lloq_multiplier => 4//3, :dev_acc => 0.15),
        :axis => Dict{Symbol, Any}(
            :title => cal -> string(cal.analyte), 
            :xlabel => "Concentration (nM)", 
            :ylabel => "Abundance", 
            :titlesize => 20
        ), 
        :cells => Dict{Symbol, Any}(
            :height => 24, 
            :font => attr(size = 12), 
            :line_color => "darkgreen", 
            :align => :right, 
            :fill_color => ["honeydew", "lightpink", "darkseagreen"], 
            :subheader_color => "rgb(235, 193, 238)", 
            :sigdigits => [4, 4, 4, 4]
        ), 
        :data => Dict{Symbol, Any}(
            :sigdigits => [4, 4, 4, 4],
            :digits => [nothing, nothing, nothing, nothing]
        ), 
        :fig => Dict{Symbol, Any}(:size => (1350, 750)), 
        :header => Dict{Symbol, Any}(
            :height => 24, 
            :font => attr(size = 12, color = "white"), 
            :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], 
            :line_color => "darkgreen", 
            :fill_color => "limegreen", 
            :align => "center"
        ), 
        :layout => Dict{Symbol, Any}(
            :title => cal -> string(cal.analyte), 
            :width => 720
        ), 
        :line => Dict{Symbol, Any}(:color => :chartreuse),
        :scatter => Dict{Symbol, Any}(
            :color => [:blue, :red], 
            :inspector_label => cal -> (self, i, p) -> string("id: ", cal.table.id[i], "\nlevel: ", cal.table.level[i], "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
        )
]

Built-in attributes templates collection.

* `acc`: definition of accuracy outliers.
    * `dev_acc`: allowed deviation of accuracy.
    * `lloq_multiplier`: multiplier of `dev_acc` for LLOQ level.
* `data`: digits settings for showing value in main GUI or exporting data. They should be 4-element vectors representing formula, LLOQ, ULOQ and R².
    * `sigdigits`: number of siginificant digits.
    * `digits`: digits after or befor decimal.  
* `axis`: attributes of `Axis`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `fig`: attributes of `Figure`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `line`: attributes of `Lines`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/).
* `scatter`: attributes of `Scatter`. Please see documentation of [`Makie.jl`](https://docs.makie.org/v0.20/). Note that a single value or a 2-element vector is valid. The latter represent values for selected (first) and unselected (second) points.
* `header`: attributes of header of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/). There sre addtional attributes:
    * `subheader_color`: the color of subheader separating calibration points and sample values of each analyes.
    * `sigdigits`: number of siginificant digits.
    * `digits`: digits after or befor decimal.  
* `cells`: attributes of cells of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/)
* `header`: attributes of header of `Table`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/table/)
* `layout`: attributes of `Layout`. Please see documentation of [`PlotlyJS`](https://plotly.com/javascript/reference/)

In template files, julia expression can be wrapped as `"@jl julia_expression"`, and string in the expression has to be chabged to `@q string...`. Reserved strings can be build from the corresponding characters. 
"""
const TEMP_ATTR = [
    :acc => Dict{Symbol, Any}(:lloq_multiplier => 4//3, :dev_acc => 0.15),
    :axis => Dict{Symbol, Any}(
        :title => cal -> string(cal.analyte), 
        :xlabel => "Concentration (nM)", 
        :ylabel => "Abundance", 
        :titlesize => 20
    ), 
    :cells => Dict{Symbol, Any}(
        :height => 24, 
        :font => attr(size = 12), 
        :line_color => "darkgreen", 
        :align => :right, 
        :fill_color => ["honeydew", "lightpink", "darkseagreen"], 
        :subheader_color => "rgb(235, 193, 238)", 
        :sigdigits => [4, 4, 4, 4]
    ), 
    :data => Dict{Symbol, Any}(
        :sigdigits => [4, 4, 4, 4],
        :sigdigits => [nothing, nothing, nothing, nothing]
    ), 
    :fig => Dict{Symbol, Any}(:size => (1350, 750)), 
    :header => Dict{Symbol, Any}(
        :height => 24, 
        :font => attr(size = 12, color = "white"), 
        :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], 
        :line_color => "darkgreen", 
        :fill_color => "limegreen", 
        :align => "center"
    ), 
    :layout => Dict{Symbol, Any}(
        :title => cal -> string(cal.analyte), 
        :width => 720
    ), 
    :line => Dict{Symbol, Any}(:color => :chartreuse),
    :scatter => Dict{Symbol, Any}(
        :color => [:blue, :red], 
        :inspector_label => cal -> (self, i, p) -> string("id: ", cal.table.id[i], "\nlevel: ", cal.table.level[i], "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
    )
]

"""
    read_temp_attr(input::AbstractString)

Read attributes template. In template files, julia expression can be wrapped as `"@jl julia_expression"`, and string in the expression has to be chabged to `@q string...`. Reserved strings can be build from the corresponding characters. 
"""
function read_temp_attr(input::AbstractString)
    ks = ["acc", "axis", "cells", "data", "fig", "header", "layout", "line", "scatter"]
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
    endswith(input, ".batch") || throw(ArgumentError("$input is not a batch directory."))
    in("calibrator", readdir(input)) || throw(ArgumentError("No calibrator directory."))
    dir = joinpath(input, "calibrator")
    ks = ["acc", "axis", "cells", "data", "fig", "header", "layout", "line", "scatter"]
    attrs = Dict([Symbol(k) => Dict{Symbol, Any}[] for k in ks]...)
    for d in readdir(dir)
        if !endswith(d, ".ecal")
            continue
        elseif "attr" in readdir(joinpath(dir, d))
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
    get_batch_attr(calibrator::Vector, temp_attrs = TEMP_ATTR)

Create valid attributes object for a batch or calibrators from a collection attributes templates.
"""
get_batch_attr(batch::Batch, temp_attrs = TEMP_ATTR) = get_batch_attr(filter(x -> x isa ExternalCalibrator, batch.calibrator), temp_attrs)
function get_batch_attr(calibrator::Vector, temp_attrs = TEMP_ATTR)
    Dict{Symbol, Any}([attr => map_attrs(dict, calibrator) for (attr, dict) in temp_attrs]...)
end

function map_attrs(dict, cal)
    [Dict{Symbol, Any}((k => (v isa Function ? v(c) : v) for (k, v) in dict)...) for c in cal]
end

# Hard coded attr for missing attr in temp_attrs
add_default_attrs!(attrs, batch::Batch) = add_default_attrs!(attrs, filter(x -> x isa ExternalCalibrator, batch.calibrator))
function add_default_attrs!(attrs, calibrator::Vector)
    for (a, v) in attrs
        for (dict, cal) in zip(v, calibrator)
            if a == :acc
                get!(dict, :lloq_multiplier, 4//3)
                get!(dict, :dev_acc, 0.15)
            elseif a == :fig
                get!(dict, :size, (1350, 750))
            elseif a == :axis 
                get!(dict, :title, string(cal.analyte))
                get!(dict, :xlabel, "Concentration (nM)")
                get!(dict, :ylabel, "Abundance")
                get!(dict, :titlesize, 20)
            elseif a == :scatter 
                get!(dict, :color, [:blue, :red])
                get!(dict, :inspector_label, (self, i, p) -> string("id: ", cal.table.id[i], 
                    "\nlevel: ", cal.table.level[i], 
                    "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
                )
            elseif a == :line 
                get!(dict, :color, :chartreuse)
            elseif a == :layout 
                get!(dict, :title, string(cal.analyte))
                get!(dict, :width, 720)
            elseif a == :header 
                get!(dict, :height, 24)
                get!(dict, :font, attr(size = 12, color = "white"))
                get!(dict, :values, ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"])
                get!(dict, :line_color, "darkgreen")
                get!(dict, :fill_color, "limegreen")
                get!(dict, :align, "center")
            elseif a == :cells 
                get!(dict, :height, 24)
                get!(dict, :font, attr(size = 12))
                get!(dict, :line_color, "darkgreen")
                get!(dict, :align, "right")
                get!(dict, :fill_color, ["honeydew", "lightpink", "darkseagreen"])
                get!(dict, :subheader_color, "rgb(235, 193, 238)")
                default_digits!(dict)
            elseif a == :data
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
    endswith(output, ".batch") || throw(ArgumentError("$output is not a batch directory."))
    in("calibrator", readdir(output)) || throw(ArgumentError("No calibrator directory. Save the batch in $output first."))
    dir = joinpath(output, "calibrator")
    ds = filter(x -> endswith(x, ".ecal"), readdir(dir))
    for (i, d) in enumerate(ds)
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
        if isnothing(d) || !isa(d, Real)
            dict[:sigdigits][i] = (isnothing(s) || !isa(s, Real)) ? 4 : s
            dict[:digits][i] = nothing
        else
            dict[:sigdigits][i] = nothing
        end
    end 
    dict
end

function join_batch_attrs(batch::Batch, calibrator;
            attrs = nothing, 
            attr_override = nothing, # :input / :temp
            attr_fallback = :input, # :input / :temp
            temp_attr = Base.Pairs{Symbol, Union{}, Tuple{}, @NamedTuple{}}[],
            input_attr...
        )
    attrs = isnothing(attrs) ? Dict{Symbol, Any}() : attrs
    ask_savelayout = isempty(attrs)
    input_attrs = nothing 
    temp_attrs = nothing
    override_attrs = Dict{Symbol, Any}()
    if attr_override == :input
        override_attrs = input_attrs = get_batch_attr(batch, input_attr)
    elseif attr_override == :temp 
        override_attrs = temp_attrs = get_batch_attr(batch, temp_attr)
    end
    fallback_attrs = Dict{Symbol, Any}()
    if attr_fallback == :input
        fallback_attrs = isnothing(input_attrs) ? get_batch_attr(batch, input_attr) : input_attrs
    elseif attr_fallback == :temp 
        fallback_attrs = isnothing(temp_attrs) ? get_batch_attr(batch, temp_attr) : temp_attrs
    end
    # each attr +> each cal
    ks = [:acc, :axis, :cells, :data, :fig, :header, :layout, :line, :scatter]
    if attr_fallback == attr_override && !isempty(override_attrs) && !isempty(fallback_attrs)
        for a in ks 
            if haskey(attrs, a) && haskey(fallback_attrs, a)
                if length(attrs[a]) != length(fallback_attrs[a]) 
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(calibrator)). Use the override and fallback attributes instead."
                    attrs[a] = fallback_attrs[a]
                    ask_savelayout = true
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in fallback_attrs[a][id]
                            ask_savelayout = ask_savelayout || (haskey(attrs[a][id], k) && attrs[a][id][k] != v)  
                            attrs[a][id][k] = v 
                        end
                    end
                end
            elseif haskey(fallback_attrs, a)
                attrs[a] = fallback_attrs[a]
                ask_savelayout = true
            end
        end
    elseif !isempty(override_attrs) && isempty(fallback_attrs)
        for a in ks 
            if haskey(attrs, a) && haskey(override_attrs, a)
                if length(attrs[a]) != length(override_attrs[a]) 
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(calibrator)). Use the override attributes instead."
                    attrs[a] = override_attrs[a]
                    ask_savelayout = true
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in attrs[a][id]
                            ask_savelayout = ask_savelayout || (haskey(override_attrs[a][id], k) && override_attrs[a][id][k] != v)  
                            attrs[a][id][k] = get(override_attrs[a][id], k, v)
                        end
                    end
                end
            end
        end
    elseif !isempty(fallback_attrs) && isempty(override_attrs)
        for a in ks 
            if haskey(attrs, a) && haskey(fallback_attrs, a)
                if length(attrs[a]) != length(fallback_attrs[a]) 
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(calibrator)). Use the fallback attributes instead."
                    attrs[a] = fallback_attrs[a]
                    ask_savelayout = true
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in fallback_attrs[a][id]
                            ask_savelayout = ask_savelayout || !haskey(attrs[a][id], k)
                            attrs[a][id][k] = get(attrs[a][id], k, v)
                        end
                    end
                end
            elseif haskey(fallback_attrs, a)
                attrs[a] = fallback_attrs[a]
                ask_savelayout = true
            end
        end
    # else
        # attrs = Dict{Symbol, Any}([a => [Dict{Symbol, Any}() for i in eachindex(calibrator)] for a in ks]...)
    end
    add_default_attrs!(attrs, batch)
    ask_savelayout, attrs
end