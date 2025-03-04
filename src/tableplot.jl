function viewtable(cal::MultipleCalibration, at, method::AnalysisMethod; 
                layout_attr = Dict{Symbol, Any}(:title => string(first(cal.analyte)), :width => 720),
                header_attr = Dict{Symbol, Any}(:height => 24, :font => attr(size = 12, color = "white"), :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], :line_color => "darkgreen", :fill_color => "limegreen", :align => "center"),
                cells_attr = Dict{Symbol, Any}(:height => 24, :font => attr(size = 12), :line_color => "darkgreen", :align => :right, :fill_color => ["honeydew", "lightpink", "darkseagreen"], :subheader_color => "rgb(235, 193, 238)", :sigdigits => [4, 4, 4, 4]),
                rel_sig = :relative_signal,
                est_conc = :estimated_concentration, 
                lloq_multiplier = 4//3, dev_acc = 0.15)
    tbl = cal.table
    # get!(layout_attr, :title, string(first(cal.analyte)))
    # get!(layout_attr, :width, 720)
    # get!(header_attr, :font, attr(size = 12, color = "white"))
    # get!(header_attr, :values, ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"])
    # get!(header_attr, :line_color, "darkgreen")
    # get!(header_attr, :fill_color, "limegreen")
    # get!(header_attr, :align, "center")
    # get!(cells_attr, :font, attr(size = 12))
    # get!(cells_attr, :line_color, "darkgreen")
    # get!(cells_attr, :align, "right")
    # get!(cells_attr, :fill_color, ["honeydew", "lightpink", "darkseagreen"])
    # get!(cells_attr, :subheader_color, "rgb(235, 193, 238)")
    # get!(cells_attr, :sigdigits, [4, 4, 4, 4])
    if !haskey(header_attr, :height)
        if haskey(header_attr, :font) && haskey(header_attr[:font].fields, :size)
            header_attr[:height] = header_attr[:font].fields[:size] * 2
        elseif haskey(header_attr, :font)
            push!(header_attr[:font].fields, :size => 12)
            header_attr[:height] = 24
        else
            push!(header_attr, :font => attr(size = 12))
            header_attr[:height] = 24
        end
    end
    if !haskey(header_attr, :height)
        if haskey(header_attr, :font) && haskey(header_attr[:font].fields, :size)
            header_attr[:height] = header_attr[:font].fields[:size] * 2
        elseif haskey(header_attr, :font)
            push!(header_attr[:font].fields, :size => 12)
            header_attr[:height] = 24
        else
            push!(header_attr, :font => attr(size = 12))
            header_attr[:height] = 24
        end
    end
    cells_attr_copy = deepcopy(cells_attr)
    haskey(cells_attr_copy, :values) && delete!(cells_attr_copy, :values)
    fc1, fc2, fc3 = get(cells_attr_copy, :fill_color, ["honeydew", "lightpink", "darkseagreen"])
    haskey(cells_attr_copy, :fill_color) && delete!(cells_attr_copy, :fill_color)
    sc = get(cells_attr_copy, :subheader_color, "rgb(235, 193, 238)")
    haskey(cells_attr_copy, :subheader_color) && delete!(cells_attr_copy, :subheader_color)
    dig = get(cells_attr_copy, :digits, [nothing, nothing, nothing, nothing])
    sig = get(cells_attr_copy, :sigdigits, [4, 4, 4, 4])
    haskey(cells_attr_copy, :sigdigits) && delete!(cells_attr_copy, :sigdigits)
    haskey(cells_attr_copy, :digits) && delete!(cells_attr_copy, :digits)
    color1 = [i ? fc1 : fc3 for i in tbl.include]
    loq_level = tbl.level[findfirst(tbl.include)]
    ft = @view tbl[tbl.level .> loq_level]
    lt = @view tbl[tbl.level .<= loq_level]
    color3 = vcat(
            [i ? (abs(j - 1) <= lloq_multiplier * dev_acc ? fc1 : fc2) : fc3 for (i, j) in zip(lt.include, lt.accuracy)],
            [i ? (abs(j - 1) <= dev_acc ? fc1 : fc2) : fc3 for (i, j) in zip(ft.include, ft.accuracy)]
            )
    layout = Layout(; layout_attr...)
    (isnothing(at) || isempty(at)) && return begin
        PlotlyJS.plot(
            table(
                header = attr(; header_attr...),
                cells = attr(;
                    values = [tbl.id, tbl.level, 
                                round.(tbl.y; sigdigits = sig[1], digits = dig[1]), 
                                round.(tbl.x; sigdigits = sig[2], digits = dig[2]), 
                                round.(tbl.x̂; sigdigits = sig[3], digits = dig[3]), 
                                round.(tbl.accuracy; sigdigits = sig[4], digits = dig[4])
                            ],
                    fill_color = vcat(repeat([c], 5), [i]),
                    cells_attr_copy...
                )
            ),
            layout
        )
    end
    j = findfirst(==(first(cal.analyte)), method.analyte)
    js = findall(==(j), method.analytetable.calibration)
    id = convert(Vector{Any}, tbl.id)
    level = convert(Vector{Any}, tbl.level)
    y = convert(Vector{Any}, round.(tbl.y; sigdigits = sig[1], digits = dig[1]))
    x = convert(Vector{Any}, round.(tbl.x; sigdigits = sig[2], digits = dig[2]))
    x̂ = convert(Vector{Any}, round.(tbl.x̂; sigdigits = sig[3], digits = dig[3]))
    acc = convert(Vector{Any}, round.(tbl.accuracy; sigdigits = sig[4], digits = dig[4]))
    cs = [id, level, y, x, x̂, acc]
    lloq, uloq = dynamic_range(cal)
    color2 = deepcopy(color1)
    for j in js
        analyte = method.analyte[j]
        ay = getanalyte(getproperty(at, rel_sig), analyte)
        ax = getanalyte(getproperty(at, est_conc), analyte)
        push!(cs[1], analyte)
        push!(color1, sc)
        push!(color2, sc)
        push!(color3, sc)
        for v in @view cs[2:end]
            push!(v, "")
        end
        append!(cs[1], sampleobj(at))
        append!(cs[2], repeat([""], length(sampleobj(at))))
        append!(cs[3], round.(ay; sigdigits = sig[1], digits = dig[1]))
        append!(cs[4], repeat([""], length(sampleobj(at))))
        append!(cs[5], round.(ax; sigdigits = sig[3], digits = dig[3]))
        append!(cs[6], repeat([""], length(sampleobj(at))))
        c2 = [(i >= lloq && i <= uloq) ? fc1 : fc2 for i in ax]
        append!(color1, repeat([fc1], length(sampleobj(at))))
        append!(color2, c2)
        append!(color3, repeat([fc1], length(sampleobj(at))))
    end
    PlotlyJS.plot(
            table(
                header = attr(; header_attr...),
                cells = attr(;
                    values = cs,
                    fill_color = vcat(repeat([color1], 4),[color2, color3]),
                    cells_attr_copy...
                )
            ),
            layout
        )

end