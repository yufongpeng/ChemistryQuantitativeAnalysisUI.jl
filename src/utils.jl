function sampletable(cal::ExternalCalibrator, at, method::AnalysisMethod; 
                layout_attr = Dict{Symbol, Any}(:title => string(cal.analyte), :width => 720),
                header_attr = Dict{Symbol, Any}(:height => 24, :font => attr(size = 12, color = "white"), :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], :line_color => "darkgreen", :fill_color => "limegreen", :align => "center"),
                cells_attr = Dict{Symbol, Any}(:height => 24, :font => attr(size = 12), :line_color => "darkgreen", :align => :right, :fill_color => ["honeydew", "lightpink", "darkseagreen"], :subheader_color => "rgb(235, 193, 238)", :sigdigits => [4, 4, 4, 4]),
                rel_sig = :relative_signal,
                est_conc = :estimated_concentration, 
                lloq_multiplier = 4//3, dev_acc = 0.15)
    tbl = cal.table
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
    j = findfirst(==(cal.analyte), method.analyte)
    js = findall(==(j), method.analytetable.std)
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
        ay = getanalyte(getproperty(at, method.rel_sig), analyte)
        ax = getanalyte(getproperty(at, method.est_conc), analyte)
        an = method.nom_conc in propertynames(at) ? map(getanalyte(getproperty(at, method.nom_conc), analyte)) do x 
                isfinite(x) ? round(x; sigdigits = sig[1], digits = dig[1]) : isnan ? missing : x 
            end : repeat([""], length(samplename(at)))
        aacc = method.nom_conc in propertynames(at) ? map(getanalyte(getproperty(at, method.acc), analyte)) do x 
                isfinite(x) ? round(x; sigdigits = sig[1], digits = dig[1]) : isnan ? missing : x 
            end : repeat([""], length(samplename(at)))
        push!(cs[1], Symbol.(analyte))
        push!(color1, sc)
        push!(color2, sc)
        push!(color3, sc)
        for v in @view cs[2:end]
            push!(v, "")
        end
        append!(cs[1], samplename(at))
        append!(cs[2], repeat([""], length(samplename(at))))
        append!(cs[3], round.(ay; sigdigits = sig[1], digits = dig[1]))
        append!(cs[4], an)
        # append!(cs[4], repeat([""], length(samplename(at))))
        append!(cs[5], round.(ax; sigdigits = sig[3], digits = dig[3]))
        append!(cs[6], aacc)
        c2 = [(i >= lloq && i <= uloq) ? fc1 : fc2 for i in ax]
        append!(color1, repeat([fc1], length(samplename(at))))
        append!(color2, c2)
        append!(color3, repeat([fc1], length(samplename(at))))
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

function calibrationdata(calibrator; data_attrs = repeat([Dict(:sigdigits => [4, 4, 4, 4], :digits => [nothing, nothing, nothing, nothing])], length(calibrator)))
    Table(; 
        analyte = [string(x.analyte) for x in calibrator],
        formula = [CQA.formula_repr_ascii(calibrator[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1]) for i in eachindex(calibrator)], 
        weight = [CQA.human_name_ascii(calibrator[i].model.weight) for i in eachindex(calibrator)], 
        LLOQ = [CQA.format_number(lloq(calibrator[i]); sigdigits = data_attrs[i][:sigdigits][2], digits = data_attrs[i][:digits][2]) for i in eachindex(calibrator)], 
        ULOQ = [CQA.format_number(uloq(calibrator[i]); sigdigits = data_attrs[i][:sigdigits][3], digits = data_attrs[i][:digits][3]) for i in eachindex(calibrator)], 
        r_squared = [CQA.format_number(r2(calibrator[i].machine); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]) for i in eachindex(calibrator)]
    )
end

function calibrationplotrange(calibrator, acc_attr, xr)
    xr = xr .+ (xr[2] - xr[1]) .* (-0.05, 0.05)
    syr = signal_range(calibrator)
    if isnan(syr[1]) && isnan(syr[2])
        yr = (minimum(calibrator.table.y), maximum(calibrator.table.y))
    elseif isnan(syr[1])
        yr = (minimum(calibrator.table.y), max(syr[2], maximum(calibrator.table.y)))
    elseif isnan(syr[2])
        yr = (min(syr[1], minimum(calibrator.table.y)), maximum(calibrator.table.y))
    else
        yr = (min(syr[1], minimum(calibrator.table.y)), max(syr[2], maximum(calibrator.table.y)))
    end
    yr = yr .* ((1 - acc_attr[:dev_acc] * acc_attr[:lloq_multiplier]), (1 + acc_attr[:dev_acc]))
    yr = yr .+ (yr[2] - yr[1]) .* (-0.05, 0.05)
    (xr, yr)
end

function calibrationxrange(xlevel)
    Table(; x = collect(LinRange(extrema(xlevel)..., convert(Int, reduce(-, extrema(xlevel)) ÷ maximum(xlevel[1:end - 1] .- xlevel[2:end]) * 100))))
end

function con_axis_attrs(fn, cal::ExternalCalibrator)
    attrs = fn(cal)
    get!(attrs, :title, string(cal.analyte))
    get!(attrs, :xlabel, "Concentration (nM)")
    get!(attrs, :ylabel, "Abundance")
    get!(attrs, :titlesize, 20)
    attrs
end

function con_scatter_attrs(fn, cal::ExternalCalibrator)
    attrs = fn(cal)
    get!(attrs, :color, [:blue, :red])
    get!(attrs, :inspector_label, (self, i, p) -> string("id: ", cal.table.id[i], 
        "\nlevel: ", cal.table.level[i], 
        "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
    )
    attrs
end

function con_line_attrs(fn, cal::ExternalCalibrator)
    attrs = fn(cal)
    get!(attrs, :color, :chartreuse)
    attrs
end

get_point_attr(scatter_attr::Dict, cal::ExternalCalibrator) = NamedTuple(k => isa(v, Vector) ? map(inc -> inc ? v[1] : v[2], cal.table.include) : v for (k, v) in scatter_attr)

function con_data_attrs(fn, cal::ExternalCalibrator)
    attrs = fn(cal)
    attrs[:sigdigits] = convert(Vector{Any}, get(attrs, :sigdigits, [nothing, nothing, nothing, nothing]))
    attrs[:digits]  = convert(Vector{Any}, get(attrs, :digits, [nothing, nothing, nothing, nothing]))
    for (i, (s, d)) in enumerate(zip(attrs[:sigdigits], attrs[:digits]))
        if isnothing(s)
            attrs[:digits][i] = isnothing(d) ? 4 : d
        elseif !isnothing(d) && !isnothing(s)
            attrs[:sigdigits][i] = nothing
        end
    end
    attrs
end

function sampletable_save(f, calibrator, batch, acc_attrs)
    for j in eachindex(calibrator)
        stable = sampletable(calibrator[j], batch.data, batch.method; lloq_multiplier = acc_attrs[j][:lloq_multiplier], dev_acc = acc_attrs[j][:dev_acc])
        file = joinpath(f, "$j.pdf")
        # calculate height to fit whole table
        height = +(stable.plot.layout.fields[:margin][:t],
                stable.plot.layout.fields[:margin][:b],
                stable.plot.data[1].fields[:cells][:height] * length(stable.plot.data[1].fields[:cells][:values][1]),
                stable.plot.data[1].fields[:header][:height]
        )
        savefig(stable, file; height)
    end
end

vectorize(x::AbstractVector) = x
vectorize(x) = [x]