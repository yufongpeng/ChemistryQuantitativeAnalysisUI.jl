# Use cal specific attr (read from directory)
# Use input attr or temp attr (read from directory) nothing / override 
"""
    cal_ui!(input::Union{Batch, <: AbstractString}; 
                tablesink = Table, 
                analytetype = String, 
                sampletype = String, 
                numbertype = Float64, 
                delim = '\t', 
                async = false,
                timeout = -1,
                root = input isa AbstractString ? input : pwd(), 
                attrs = nothing,
                attr_override = nothing, # :input / :temp
                attr_fallback = :input, # :input / :temp
                temp_attr = Base.Pairs{Symbol, Union{}, Tuple{}, @NamedTuple{}}[],
                input_attr...
            )

Interactively calibrate signal and concentration.

# Arguments
* `input`: `Batch` or `AbstractString`.
* `tablesink`: table sink for reading input file as `Batch`.
* `analytetype`: analyte type for reading input file as `Batch`.
* `sampletype`: sample type for reading input file as `Batch`.
* `numbertype`: number type for reading input file as `Batch`.
* `delim`: delim for reading input file as `Batch`.
* `async`: `Bool`, run gui asynchronously.
* `timeout`: `Number`, maximum wait time before closing the gui. -1 inidicates no limit.
* `root`: root directory for saving objects.
* `attrs`: `Dict` mapping attribute to a vector of `Dict` for each calibration. It is read from a valid batch directory `root` or becomes an empty dictionary by setting it `nothing` (default).
* `attr_override`: use input_attr (`:input`), temp_attr (`:temp`) or nothing to override defined attributes in `attrs`.
* `attr_fallback`: use input_attr (`:input`), temp_attr (`:temp`) or nothing for undefined attributes in `attrs`.
* `temp_attr`: attributes templates collection, a vector of object(`Symbol`)-attributes template(`Dict`) pairs. Please see `TEMP_ATTR` for detailed description of attributes.
* `input_attr`: keyword arguments which keys are objects, values are attributes template for each object. Please see `TEMP_ATTR` for detailed description of attributes.
"""
function cal_ui!(input::Union{Batch, <: AbstractString}; 
                tablesink = Table, 
                analytetype = String, 
                sampletype = String, 
                numbertype = Float64, 
                delim = '\t', 
                async = false,
                timeout = -1,
                root = input isa AbstractString ? input : pwd(), 
                attrs = nothing, 
                attr_override = nothing, # :input / :temp
                attr_fallback = :input, # :input / :temp
                temp_attr = Base.Pairs{Symbol, Union{}, Tuple{}, @NamedTuple{}}[],
                input_attr...
            )
    if input isa AbstractString
        batch = ChemistryQuantitativeAnalysis.read(input, tablesink; analytetype, sampletype, numbertype, delim)
    else
        batch = input
    end
    isempty(batch.calibration) && init_calibration!(batch)
    update_quantification!(batch)
    if endswith(root, ".batch")
        ChemistryQuantitativeAnalysis.write(root, batch)
        attrs = isnothing(attrs) ? read_batch_attr(root) : attrs
    end
    attrs = isnothing(attrs) ? Dict{Symbol, Any}() : attrs
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
    ks = [:acc_attr, :axis_attr, :cells_attr, :data_attr, :fig_attr, :header_attr, :layout_attr, :line_attr, :scatter_attr]
    if attr_fallback == attr_override && !isempty(override_attrs) && !isempty(fallback_attrs)
        for a in ks 
            if haskey(attrs, a) && haskey(fallback_attrs, a)
                if length(attrs[a]) != length(fallback_attrs[a]) 
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(batch.calibration)). Use the override and fallback attributes instead."
                    attrs[a] = fallback_attrs[a]
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in fallback_attrs[a][id]
                            attrs[a][id][k] = v 
                        end
                    end
                end
            elseif haskey(fallback_attrs, a)
                attrs[a] = fallback_attrs[a]
            end
        end
    elseif !isempty(override_attrs) && isempty(fallback_attrs)
        for a in ks 
            if haskey(attrs, a) && haskey(override_attrs, a)
                if length(attrs[a]) != length(override_attrs[a]) 
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(batch.calibration)). Use the override attributes instead."
                    attrs[a] = override_attrs[a]
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in attrs[a][id]
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
                    @warn "Default attributes applys to $(length(attrs[a])) calibration curve, while the batch has $(length(batch.calibration)). Use the fallback attributes instead."
                    attrs[a] = fallback_attrs[a]
                else
                    for id in eachindex(attrs[a])
                        for (k, v) in fallback_attrs[a][id]
                            attrs[a][id][k] = get(attrs[a][id], k, v)
                        end
                    end
                end
            elseif haskey(fallback_attrs, a)
                attrs[a] = fallback_attrs[a]
            end
        end
    else
        attrs = Dict{Symbol, Any}([a => [Dict{Symbol, Any}() for i in eachindex(batch.calibration)] for a in ks]...)
    end
    add_default_attrs!(attrs, batch)
    acc_attrs = attrs[:acc_attr]
    axis_attrs = attrs[:axis_attr]
    cells_attrs = attrs[:cells_attr]
    data_attrs = attrs[:data_attr]
    fig_attrs = attrs[:fig_attr]
    header_attrs = attrs[:header_attr]
    layout_attrs = attrs[:layout_attr]
    line_attrs = attrs[:line_attr]
    scatter_attrs = attrs[:scatter_attr] 
    fig = Figure(; fig_attrs[begin]...)
    # axis_attrs = con_axis_attrs.(axis_attr, batch.calibration)
    # scatter_attrs = con_scatter_attrs.(scatter_attr, batch.calibration)
    # line_attrs = con_line_attrs.(line_attr, batch.calibration)
    # layout_attrs = map(layout_attr, batch.calibration)
    # header_attrs = map(header_attr, batch.calibration)
    # cells_attrs = map(cells_attr, batch.calibration)
    # data_attrs = con_data_attrs.(data_attr, batch.calibration)
    # if acc_attrs[begin][:lloq_multiplier] isa AbstractVector
    #     ls = acc_attrs[begin][:lloq_multiplier] 
    #     for (acc, l) in zip(acc_attrs, ls)
    #         acc[:lloq_multiplier] = l 
    #     end
    # end
    # if acc_attrs[begin][:dev_acc] isa AbstractVector
    #     ls = acc_attrs[begin][:dev_acc] 
    #     for (acc, l) in zip(acc_attrs, ls)
    #         acc[:dev_acc] = l 
    #     end
    # end
    i = 1
    info = Window()
    function draw()
        tbl = viewtable(batch.calibration[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = get(acc_attrs[i], :lloq_multiplier, 4//3), dev_acc = get(acc_attrs[i], :dev_acc, 0.15))
        label_analyte = Label(fig, string(first(batch.calibration[i].analyte)); halign = :left, width = 250)
        label_lp = Label(fig, string(length(unique(batch.calibration[i].table.x[batch.calibration[i].table.include])), " levels, ", count(batch.calibration[i].table.include), " points"); halign = :left)
        button_left = Button(fig, label = "<")
        button_right = Button(fig, label = ">")
        label_r2 = Label(fig, "R² = $(round(r2(batch.calibration[i].model); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]))"; halign = :left)
        label_formula = Label(fig, formula_repr(batch.calibration[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1]); halign = :left)
        menu_type = Menu(fig, options = ["linear", "quadratic"], default = batch.calibration[i].type ? "linear" : "quadratic", tellwidth = false)
        menu_zero = Menu(fig, options = ["ignore (0, 0)", "include (0, 0)"], default = batch.calibration[i].zero ? "include (0, 0)" : "ignore (0, 0)", tellwidth = false)
        default_w = weight_repr(batch.calibration[i])
        menu_wt = Menu(fig, options = ["none", "1/√x", "1/x", "1/x²"], default = default_w)
        menu_zoom = Menu(fig, options = string.(0:length(unique(batch.calibration[i].table.x))), default = "0", tellwidth = false)
        # menu_show = Menu(fig, options = ["Cal", "Sample"], default = "Cal"; halign = :left, tellwidth = false)
        menu_export = Menu(fig, options = ["Fig", "Data", "Table"], default = "Fig"; halign = :left, tellwidth = false)
        ax = Axis(fig[1, 1]; axis_attrs[i]...)
        sc = scatter!(ax, batch.calibration[i].table.x, batch.calibration[i].table.y; get_point_attr(scatter_attrs[i], batch.calibration[i])...)
        DataInspector(sc)
        xlevel = unique(batch.calibration[i].table.x)
        xscale = -reduce(-, extrema(xlevel))
        yscale = -reduce(-, extrema(batch.calibration[i].table.y))
        xrange = Table(; x = collect(LinRange(extrema(xlevel)..., convert(Int, reduce(-, extrema(xlevel)) ÷ maximum(xlevel[1:end - 1] .- xlevel[2:end]) * 100))))
        ln = lines!(ax, xrange.x, predict(batch.calibration[i].model, xrange); line_attrs[i]...)
        tall = Menu(fig, options = ["All analytes", "This analyte"], default = "All analytes")
        objs = Dict(:axis => ax, :scatter => sc, :line => ln)
        menu_obj = Menu(fig, options = vcat(collect(keys(objs)), [:layout, :header, :cells, :acc, :data]), default = "axis", halign = :left)
        button_confirm = Button(fig, label = "confirm", halign = :left)    
        textbox_attr = Textbox(fig, placeholder = "attribute", tellwidth = false, halign = :left)
        textbox_value = Textbox(fig, placeholder = "value (julia expression)", tellwidth = false, halign = :left)
        button_show = Button(fig, label = "Table")
        button_export = Button(fig, label = "export")
        button_save = Button(fig, label = "Save batch "; halign = :left)
        button_saveas = Button(fig, label = "Save batch as")
        lzoom = Label(fig, "Zoom")
        ltype = Label(fig, "Type")
        lzero = Label(fig, "Zero")
        lweight = Label(fig, "Weight")
        lps = Label(fig, "Plot setting", halign = :left, tellwidth = false)
        lc = [label_analyte, label_lp, button_left, button_right, label_r2, label_formula, lzoom, menu_zoom, 
            ltype, menu_type, lzero, menu_zero, lweight, menu_wt, lps, tall, menu_obj, textbox_attr, button_confirm, textbox_value, 
            menu_export, button_show, button_export, button_save, button_saveas]
        fig[1, 2] = vgrid!(
            label_analyte, 
            hgrid!(label_lp, button_left, button_right; halign = :left),
            label_r2,
            label_formula,
            hgrid!(lzoom, menu_zoom),
            hgrid!(ltype, menu_type), 
            hgrid!(lzero, menu_zero),
            hgrid!(lweight, menu_wt),
            hgrid!(lps, tall),
            menu_obj, 
            hgrid!(textbox_attr, button_confirm),
            textbox_value, 
            hgrid!(button_show, menu_export, button_export), 
            hgrid!(button_save, button_saveas);
            tellheight = false
        )
        xr = dynamic_range(batch.calibration[i])
        xr = xr .+ (xr[2] - xr[1]) .* (-0.05, 0.05)
        yr = signal_range(batch.calibration[i]) .* ((1 - get(acc_attrs[i], :dev_acc, 0.15) * get(acc_attrs[i], :lloq_multiplier, 4//3)), (1 + get(acc_attrs[i], :dev_acc, 0.15)))
        yr = yr .+ (yr[2] - yr[1]) .* (-0.05, 0.05)
        limits!(ax, xr, yr)
        body!(info, tbl)
        #display(view_sample(sample; lloq = batch.calibration[i].table.x[findfirst(batch.calibration[i].table.include)], uloq = batch.calibration[i].table.x[findlast(batch.calibration[i].table.include)], lloq_multiplier, dev_acc))
        # Main.vscodedisplay(batch.calibration[i].table[batch.calibration[i].table.include])
        # fig[1, 3] = vgrid!(map(s -> Label(fig, s; halign = :left), split(sprint(showtable, batch.calibration[i].table), "\n"))...; tellheight = false, width = 250)
        function update!()
            update_calibration!(batch.calibration[i], batch.method)
            update_quantification!(batch)
            ln.args[2][] = predict(batch.calibration[i].model, xrange)
            label_lp.text = string(length(unique(batch.calibration[i].table.x[batch.calibration[i].table.include])), " levels, ", count(batch.calibration[i].table.include), " points")
            label_r2.text = "R² = $(round(r2(batch.calibration[i].model); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]))"
            label_formula.text = formula_repr(batch.calibration[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1])
            button_save.label = "Save batch "
            #sample.x̂ .= inv_predict(batch.calibration[i], sample)
            tbl = viewtable(batch.calibration[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = get(acc_attrs[i], :lloq_multiplier, 4//3), dev_acc = get(acc_attrs[i], :dev_acc, 0.15))
            body!(info, tbl)
        end
        function update_analyte!()
            for x in lc
                delete!(x)
            end
            delete!(ax)
            draw()
        end
        on(button_left.clicks) do s
            j = max(i - 1, firstindex(batch.calibration))
            if j != i
                i = j
                update_analyte!()
            end
        end
        on(button_right.clicks) do s
            j = min(i + 1, lastindex(batch.calibration))
            if j != i
                i = j
                update_analyte!()
            end
        end
        on(events(ax).mousebutton) do event
            if event.action == Mouse.press
                plot, id = pick(ax)
                if id != 0 && plot == sc
                    if event.button == Mouse.left
                        ro = batch.calibration[i].table[id]
                        ids = findall(x -> x.x == ro.x && isapprox(x.y, ro.y), batch.calibration[i].table)
                        for id in ids
                            batch.calibration[i].table.include[id] = !batch.calibration[i].table.include[id]
                        end
                        delete!(ax, sc)
                        sc = scatter!(ax, batch.calibration[i].table.x, batch.calibration[i].table.y; get_point_attr(scatter_attrs[i], batch.calibration[i])...)
                        DataInspector(sc)
                        update!()
                    end
                end
            end
            return Consume(false)
        end
        on(menu_type.selection) do s
            batch.calibration[i].type = s == "linear"
            update!()
        end
        on(menu_zero.selection) do s
            batch.calibration[i].zero = s == "include (0, 0)"
            update!()
        end
        on(menu_wt.selection) do s
            batch.calibration[i].weight = weight_value(s)
            update!()
        end
        on(menu_zoom.selection) do s
            s = parse(Int, s)
            if s == 0
                #autolimits!(ax)
                xr = dynamic_range(batch.calibration[i])
                xr = xr .+ (xr[2] - xr[1]) .* (-0.05, 0.05)
                yr = signal_range(batch.calibration[i]) .* ((1 - get(acc_attrs[i], :dev_acc, 0.15) * get(acc_attrs[i], :lloq_multiplier, 4//3)), (1 + get(acc_attrs[i], :dev_acc, 0.15)))
                yr = yr .+ (yr[2] - yr[1]) .* (-0.05, 0.05)
                limits!(ax, xr, yr)
            else
                x_value = xlevel[s] 
                id = findall(==(x_value), batch.calibration[i].table.x)
                y_value = batch.calibration[i].table.y[id]
                Δy = length(unique(y_value)) == 1 ? abs(0.2 * y_value[1]) : -reduce(-, extrema(y_value))
                yl = extrema(y_value) .+ (-Δy, Δy)
                Δx = Δy * xscale / yscale
                xl = x_value .+ (-Δx, Δx)
                if isapprox(xl...)
                    xl = x_value .+ (-eps(), eps())
                end
                if isapprox(yl...)
                    yl = y_value .+ (-eps(), eps())
                end
                limits!(ax, xl, yl)
            end
        end
        on(button_confirm.clicks) do s
            button_save.label = "Save batch "
            # acc_attr, data_attr
            if menu_obj.selection[] == :data
                nattr = Symbol(textbox_attr.stored_string[])
                oattrs = deepcopy(data_attrs)
                if tall.selection[] == "All analytes"
                    for j in eachindex(data_attrs)
                        data_attrs[j][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                        try 
                            @assert data_attrs[j][:digits] isa Vector 
                            @assert length(data_attrs[j][:digits]) == 4 
                            @assert data_attrs[j][:sigdigits] isa Vector 
                            @assert length(data_attrs[j][:sigdigits]) == 4
                            default_digits!(data_attrs[j])
                        catch e
                            data_attrs[j][nattr] = oattrs[j][nattr]
                            @warn e
                        end
                    end
                else
                    data_attrs[i][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                    try 
                        @assert data_attrs[i][:digits] isa Vector 
                        @assert length(data_attrs[i][:digits]) == 4 
                        @assert data_attrs[i][:sigdigits] isa Vector 
                        @assert length(data_attrs[i][:sigdigits]) == 4
                        default_digits!(data_attrs[i])
                    catch e
                        data_attrs[i][nattr] = oattrs[i][nattr]
                        @warn e
                    end
                end
                try 
                    Table(; 
                        formula = [formula_repr_ascii(batch.calibration[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1])], 
                        weight = [weight_repr_ascii(batch.calibration[i])], 
                        LLOQ = [format_number(lloq(batch.calibration[i]); sigdigits = data_attrs[i][:sigdigits][2], digits = data_attrs[i][:digits][2])], 
                        ULOQ = [format_number(uloq(batch.calibration[i]); sigdigits = data_attrs[i][:sigdigits][3], digits = data_attrs[i][:digits][3])], 
                        r_squared = [format_number(r2(batch.calibration[i].model); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4])])
                    label_r2.text = "R² = $(round(r2(batch.calibration[i].model); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]))"
                    label_formula.text = formula_repr(batch.calibration[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1])
                catch e 
                    attrs[:data_attr] = data_attrs = oattrs
                    throw(e)
                end
                return
            elseif menu_obj.selection[] in [:layout, :header, :cells, :acc]
                nattr = Symbol(textbox_attr.stored_string[])
                if menu_obj.selection[] == :acc
                    oattrs = deepcopy(acc_attrs)
                    if tall.selection[] == "All analytes"
                        for j in eachindex(acc_attrs)
                            acc_attrs[j][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                        end
                    else
                        acc_attrs[i][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                elseif menu_obj.selection[] == :layout
                    oattrs = deepcopy(layout_attrs)
                    if tall.selection[] == "All analytes"
                        for j in eachindex(layout_attrs)
                            layout_attrs[j][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                        end
                    else
                        layout_attrs[i][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                elseif menu_obj.selection[] == :header
                    oattrs = deepcopy(header_attrs)
                    if tall.selection[] == "All analytes"
                        for j in eachindex(header_attrs)
                            header_attrs[j][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                        end
                    else
                        header_attrs[i][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                else
                    oattrs = deepcopy(cells_attrs)
                    if tall.selection[] == "All analytes"
                        for j in eachindex(cells_attrs)
                            cells_attrs[j][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                            try 
                                @assert cells_attrs[j][:digits] isa Vector 
                                @assert length(cells_attrs[j][:digits]) == 4 
                                @assert cells_attrs[j][:sigdigits] isa Vector 
                                @assert length(cells_attrs[j][:sigdigits]) == 4
                                default_digits!(cells_attrs[j])
                            catch e
                                cells_attrs[j][nattr] = oattrs[j][nattr]
                                @warn e
                            end
                        end
                    else
                        cells_attrs[i][nattr] = eval(Meta.parse(textbox_value.stored_string[]))
                        try 
                            @assert cells_attrs[i][:digits] isa Vector 
                            @assert length(cells_attrs[i][:digits]) == 4 
                            @assert cells_attrs[i][:sigdigits] isa Vector 
                            @assert length(cells_attrs[i][:sigdigits]) == 4
                            default_digits!(cells_attrs[i])
                        catch e
                            cells_attrs[i][nattr] = oattrs[i][nattr]
                            @warn e
                        end
                    end
                end
                try
                    tbl = viewtable(batch.calibration[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = get(acc_attrs[i], :lloq_multiplier, 4//3), dev_acc = get(acc_attrs[i], :dev_acc, 0.15))
                    body!(info, tbl)
                catch e 
                    if menu_obj.selection[] == :acc_attrs
                        attrs[:acc_attr] = acc_attrs = oattrs
                    elseif menu_obj.selection[] == :layout
                        attrs[:layout_attr] = layout_attrs = oattrs
                    elseif menu_obj.selection[] == :header
                        attrs[:header_attr] = header_attrs = oattrs
                    else 
                        attrs[:cells_attr] = cells_attrs = oattrs
                    end
                    tbl = viewtable(batch.calibration[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = get(acc_attrs[i], :lloq_multiplier, 4//3), dev_acc = get(acc_attrs[i], :dev_acc, 0.15))
                    body!(info, tbl)
                    throw(e)
                end
                return
            elseif menu_obj.selection[] == :scatter
                attr = Symbol(textbox_attr.stored_string[])
                isnothing(attr) && return
                oscatter_attrs = deepcopy(scatter_attrs)
                if tall.selection[] == "All analytes"
                    for j in eachindex(scatter_attrs)
                        scatter_attrs[j][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                else
                    scatter_attrs[i][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                end
                try 
                    delete!(ax, sc)
                    sc = scatter!(ax, batch.calibration[i].table.x, batch.calibration[i].table.y; get_point_attr(scatter_attrs[i], batch.calibration[i])...)
                    DataInspector(sc)
                catch e 
                    attrs[:scatter_attr] = scatter_attrs = oscatter_attrs
                    sc = scatter!(ax, batch.calibration[i].table.x, batch.calibration[i].table.y; get_point_attr(scatter_attrs[i], batch.calibration[i])...)
                    DataInspector(sc)
                    throw(e)
                end
                return
            elseif menu_obj.selection[] == :line
                attr = Symbol(textbox_attr.stored_string[])
                oline_attrs = deepcopy(line_attrs)
                if tall.selection[] == "All plots"
                    for j in eachindex(line_attrs)
                        line_attrs[j][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                else
                    line_attrs[i][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                end
            elseif menu_obj.selection[] == :axis
                attr = Symbol(textbox_attr.stored_string[])
                oaxis_attrs = deepcopy(axis_attrs)
                if tall.selection[] == "All plots"
                    for j in eachindex(axis_attrs)
                        axis_attrs[j][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                    end
                else
                    axis_attrs[i][attr] = eval(Meta.parse(textbox_value.stored_string[]))
                end
            end
            try
                x = getproperty(objs[menu_obj.selection[]], Symbol(textbox_attr.stored_string[]))[]
                if length(vectorize(x)) > 1 
                    setproperty!(objs[menu_obj.selection[]], Symbol(textbox_attr.stored_string[]), repeat([eval(Meta.parse(textbox_value.stored_string[]))], length(x)))
                else
                    setproperty!(objs[menu_obj.selection[]], Symbol(textbox_attr.stored_string[]), eval(Meta.parse(textbox_value.stored_string[]))) 
                end
            catch e 
                if menu_obj.selection[] == :line
                    attrs[:line_attr] = line_attrs = oline_attrs
                elseif menu_obj.selection[] == :axis
                    attrs[:axis_attr] = axis_attrs = oaxis_attrs
                end
                throw(e)
            end
        end
        on(button_show.clicks) do s
            if !active(info) 
                info = Window()
                tbl = viewtable(batch.calibration[i], batch.data, batch.method; lloq_multiplier = get(acc_attrs[i], :lloq_multiplier, 4//3), dev_acc = get(acc_attrs[i], :dev_acc, 0.15))
                body!(info, tbl)
            end
                #Main.vscodedisplay(batch.calibration[i].table[batch.calibration[i].table.include])
        end
        on(button_export.clicks) do s
            if menu_export.selection[] == "Fig"
                save_dialog("Save figure as", nothing, ["*.png"]; start_folder = root) do f
                    f == "" || save(f, fig; update = false)
                end
            elseif menu_export.selection[] == "Data"
                save_dialog("Save data as", nothing, ["*.csv"]; start_folder = root) do f
                    f == "" || CSV.write(f, Table(; 
                        formula = [formula_repr_ascii(batch.calibration[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1])], 
                        weight = [weight_repr_ascii(batch.calibration[i])], 
                        LLOQ = [format_number(lloq(batch.calibration[i]); sigdigits = data_attrs[i][:sigdigits][2], digits = data_attrs[i][:digits][2])], 
                        ULOQ = [format_number(uloq(batch.calibration[i]); sigdigits = data_attrs[i][:sigdigits][3], digits = data_attrs[i][:digits][3])], 
                        r_squared = [format_number(r2(batch.calibration[i].model); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4])]))
                end
            elseif menu_export.selection[] == "Table"
                save_dialog("Save table as", nothing, ["*.png", "*.jpeg", "*.webp", "*.svg", "*.pdf", "*.eps", "*.pdf", "*.html", "*.json"]; start_folder = root) do f
                    # calculate height to fit whole table
                    height = +(tbl.plot.layout.fields[:margin][:t],
                            tbl.plot.layout.fields[:margin][:b],
                            tbl.plot.data[1].fields[:cells][:height] * length(tbl.plot.data[1].fields[:cells][:values][1]),
                            tbl.plot.data[1].fields[:header][:height]
                    )
                    f == "" || savefig(tbl, f; height)
                end
            end
            #=
            if menu_show_export.selection[] == "All"
                save_dialog("Save as", nothing; start_folder = pwd()) do f
                    f == "" && return
                    mkpath(f)
                    j = i
                    for id in eachindex(plot_attrs)
                        i = id
                        update_analyte!()
                        sleep(1)
                        save(joinpath(f, "plot_$i.png"), fig; update = false)
                        CSV.write(joinpath(f, "cal_$i.csv"), Table(; formula = [formula_repr_asciii(batch.calibration[i])], weight = [weight_repr_asciii(batch.calibration[i])], LLOQ = [format_number(lloq(batch.calibration[i]))], ULOQ = [format_number(uloq(batch.calibration[i]))],  r_squared = [format_number(r2(batch.calibration[i].model))]))
                    end
                    i = j
                    update_analyte!()
                end
            end
            =#
        end
        on(button_saveas.clicks) do s
            save_dialog("Save as", nothing, ["*.batch"]; start_folder = root) do f
                f == "" || (ChemistryQuantitativeAnalysis.write(f, batch); write_batch_attr(f, attrs); root = f)
            end
        end
        on(button_save.clicks) do s
            if endswith(root, ".batch")
                ChemistryQuantitativeAnalysis.write(root, batch)
                # save attr 
                write_batch_attr(root, attrs)
                button_save.label = "Batch saved"
            else
                save_dialog("Save as", nothing, ["*.batch"]; start_folder = root) do f
                    f == "" || (ChemistryQuantitativeAnalysis.write(f, batch); save_batch_attr(f, attrs); root = f)
                end
            end
        end
    end
    draw()
    f = display(fig)
    if async
        if timeout > 0
            t = Task(() -> begin
                        timedwait(() -> !f.window_open[], timeout)
                        close(f)
                        close(info)
                    end)
        else
            t = Task(() -> begin
                        wait(f)
                        close(info)
                    end)
        end
        schedule(t)
    elseif timeout > 0
        timedwait(() -> !f.window_open[], timeout)
        close(f)
        close(info)
    else
        wait(f)
        close(info)
    end
    return
end

function con_axis_attrs(fn, cal::MultipleCalibration)
    attrs = fn(cal)
    get!(attrs, :title, string(first(cal.analyte)))
    get!(attrs, :xlabel, "Concentration (nM)")
    get!(attrs, :ylabel, "Abundance")
    get!(attrs, :titlesize, 20)
    attrs
end

function con_scatter_attrs(fn, cal::MultipleCalibration)
    attrs = fn(cal)
    get!(attrs, :color, [:blue, :red])
    get!(attrs, :inspector_label, (self, i, p) -> string("id: ", cal.table.id[i], 
        "\nlevel: ", cal.table.level[i], 
        "\naccuracy: ", round(cal.table.accuracy[i]; sigdigits = 4))
    )
    attrs
end
function con_line_attrs(fn, cal::MultipleCalibration)
    attrs = fn(cal)
    get!(attrs, :color, :chartreuse)
    attrs
end
# function con_table_attrs(fn, cal::MultipleCalibration)
#     attrs = fn(cal)
#     get!(attrs, :layout_attr, Dict{Symbol, Any}(:title => string(first(cal.analyte)), :width => 720))
#     get!(attrs, :header_attr, Dict{Symbol, Any}(:height => 24, :font => attr(size = 12, color = "white"), :values => ["Sample", "Level", "Y", "X", "Predicted X", "Accuracy"], :line_color => "darkgreen", :fill_color => "limegreen", :align => "center"))
#     get!(attrs, :cells_attr, Dict{Symbol, Any}(:height => 24, :font => attr(size = 12), :line_color => "darkgreen", :align => :right, :fill_color => ["honeydew", "lightpink", "darkseagreen"], :subheader_color => "rgb(235, 193, 238)", :sigdigits => [4, 4, 4, 4]))
#     attrs 
# end
#get_point_attr(plot_attr::Dict, incl::Bool) = NamedTuple(k => incl ? v[1] : v[2] for (k, v) in get!(plot_attr, :scatter, Dict(:color => [:blue, :red])))
#get_point_attr(plot_attr::Dict, incl::BitVector) = NamedTuple(k => isa(v, Vector) ? map(inc -> inc ? v[1] : v[2], incl) : v for (k, v) in get!(plot_attr, :scatter, Dict(:color => [:blue, :red])))
#get_point_attr(plot_attr::Dict, incl::Vector{Bool}) = NamedTuple(k => isa(v, Vector) ? map(inc -> inc ? v[1] : v[2], incl) : v for (k, v) in get!(plot_attr, :scatter, Dict(:color => [:blue, :red])))
get_point_attr(scatter_attr::Dict, cal::MultipleCalibration) = NamedTuple(k => isa(v, Vector) ? map(inc -> inc ? v[1] : v[2], cal.table.include) : v for (k, v) in scatter_attr)
#get_axis_attr(axis_attr::Dict, cal::MultipleCalibration) = NamedTuple(k => v isa Function ? v(cal) : v for (k, v) in axis_attr)
function con_data_attrs(fn, cal::MultipleCalibration)
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

vectorize(x::AbstractVector) = x
vectorize(x) = [x]