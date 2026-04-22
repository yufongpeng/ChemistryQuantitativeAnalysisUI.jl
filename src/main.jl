# Use cal specific attr (read from directory)
# Use input attr or temp attr (read from directory) nothing / override 
"""
    ChemistryQuantitativeAnalysisUI.run!(
        input::Union{Batch, <: AbstractString}; 
        tablesink = Table, 
        analytetype = String, 
        sampletype = String, 
        numbertype = Float64, 
        modeltype = CalibrationModel, 
        delim = '\t', 
        async = false,
        timeout = -1,
        dir = input isa AbstractString ? dirname(input) : pwd(), 
        file = "batch",
        newfile = true, 
        attrs = nothing,
        attr_override = nothing, # :input / :temp
        attr_fallback = :input, # :input / :temp
        temp_attr = Base.Pairs{Symbol, Union{}, Tuple{}, @NamedTuple{}}[],
        input_attr...
    )

Interactively calibrate signal and concentration.

# Arguments
* `input`: `Batch` or `AbstractString` (".batch" directory).
* `tablesink`: table sink for reading input file as `Batch`.
* `analytetype`: analyte type for reading input file as `Batch`.
* `sampletype`: sample type for reading input file as `Batch`.
* `numbertype`: number type for reading input file as `Batch`.
* `modeltype`: calibration type for reading input file as `Batch`.
* `delim`: delim for reading input file as `Batch`.
* `async`: `Bool`, run gui asynchronously.
* `timeout`: `Number`, maximum wait time before closing the gui. -1 inidicates no limit.
* `dir`: directory for saving objects. If the input is not a ".batch" directory, a new batch with name `file`.batch (or `file`(1).batch ...) is generated in `dir`.
* `file`: filename of batch. If the input is not a ".batch" directory, a new batch with name `file`.batch (or `file`(1).batch ...) is generated in `dir`.
* `newfile`: whether a new `file`(1).batch is generated if `file`.batch already exists.
* `attrs`: `Dict` mapping attribute to a vector of `Dict` for each calibration. It is read from a valid batch directory `dir` or becomes an empty dictionary by setting it `nothing` (default).
* `attr_override`: use input_attr (`:input`), temp_attr (`:temp`) or nothing to override defined attributes in `attrs`.
* `attr_fallback`: use input_attr (`:input`), temp_attr (`:temp`) or nothing for undefined attributes in `attrs`.
* `temp_attr`: attributes templates collection, a vector of object(`Symbol`)-attributes template(`Dict`) pairs. Please see `TEMP_ATTR` for detailed description of attributes.
* `input_attr`: keyword arguments which keys are objects, values are attributes template for each object. Please see `TEMP_ATTR` for detailed description of attributes.
"""
function run!(input::Union{Batch, <: AbstractString}; 
            tablesink = Table, 
            analytetype = String, 
            sampletype = String, 
            numbertype = Float64, 
            modeltype = CalibrationModel, 
            delim = '\t', 
            async = false,
            timeout = -1,
            dir = input isa AbstractString ? dirname(input) : pwd(), 
            file = "batch", 
            newfile = true, 
            attrs = nothing, 
            attr_override = nothing, # :input / :temp
            attr_fallback = :temp, # :input / :temp
            temp_attr = TEMP_ATTR,
            input_attr...
        )
    ask_savebatch = true
    ask_savelayout = false
    if input isa AbstractString
        batch = ChemistryQuantitativeAnalysis.read(input, tablesink; analytetype, sampletype, numbertype, modeltype, delim)
        batchdir = Ref{String}()
        batchdir[] = input
        dir = Ref{String}(dir)
        ask_savebatch = false
        if isnothing(attrs) 
            try 
                attrs = read_batch_attr(input) 
            catch e 
                @warn e
                attrs = nothing
            end
        end
    else
        batch = input
        dir = Ref{String}(dir)
        dirs = readdir(dir[])
        filename = string(file, ".batch")
        if newfile
            i = 0
            while !isnothing(findfirst(==(filename), dirs))
                i += 1
                filename = string(file, "(", i, ").batch")
            end
        end
        batchdir = Ref{String}(joinpath(dir[], filename))
    end
    isempty(batch.calibrator) ? calibrate!(batch) : model_calibrator!(batch)
    analyze!(batch)
    calibrator = filter(x -> x isa ExternalCalibrator, batch.calibrator)
    analyte_id = map(x -> findfirst(==(x.analyte), batch.analyte), calibrator)
    _ask_savelayout, attrs = join_batch_attrs(batch, calibrator; attrs, attr_override, attr_fallback, temp_attr, input_attr...)
    ask_savelayout = ask_savelayout || _ask_savelayout
    acc_attrs = attrs[:acc]
    axis_attrs = attrs[:axis]
    cells_attrs = attrs[:cells]
    data_attrs = attrs[:data]
    fig_attrs = attrs[:fig]
    header_attrs = attrs[:header]
    layout_attrs = attrs[:layout]
    line_attrs = attrs[:line]
    scatter_attrs = attrs[:scatter] 
    fig = Figure(; fig_attrs[begin]...)
    component = Any[]
    main = display(fig)
    i = 1
    analytes = map(x -> string(x.analyte), calibrator)
    table_window = Window()
    table_channel = Channel(1)
    put!(table_channel, table_window)
    function schedule_main()
        if async
            if timeout > 0
                t = Task(() -> begin
                            timedwait(() -> !main.window_open[], timeout)
                            close(main)
                            table_window = take!(table_channel)
                            close(table_window)
                            # ask_savebatch && wait(ask_savebatch_close())
                            # ask_savelayout && wait(ask_savelayout_close())
                        end)
            else
                t = Task(() -> begin
                            wait(main)
                            table_window = take!(table_channel)
                            close(table_window)
                            # ask_savebatch && wait(ask_savebatch_close())
                            # ask_savelayout && wait(ask_savelayout_close())
                        end)
            end
            schedule(t)
        elseif timeout > 0
            timedwait(() -> !main.window_open[], timeout)
            close(main)
            table_window = take!(table_channel)
            close(table_window)
            # ask_savebatch && wait(ask_savebatch_close())
            # ask_savelayout && wait(ask_savelayout_close())
        else
            wait(main)
            table_window = take!(table_channel)
            close(table_window)
            # ask_savebatch && wait(ask_savebatch_close())
            # ask_savelayout && wait(ask_savelayout_close())
        end
    end
    function draw!(; message = nothing, origin = nothing, widths = nothing)
        menu_analyte = Menu(fig; options = analytes, default = analytes[i], halign = :left, tellwidth = true)
        label_lp = Label(fig, string(length(unique(calibrator[i].table.x[calibrator[i].table.include])), " levels, ", count(calibrator[i].table.include), " points"); halign = :left, tellwidth = true)
        label_r2 = Label(fig, "R² = $(round(r2(calibrator[i].machine); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]))"; halign = :left, tellwidth = true)
        label_formula = Label(fig, CQA.formula_repr(calibrator[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1]); halign = :left, tellwidth = true)
        menu_type = Menu(fig; options = TYPE_OPTIONS, default = default_type(calibrator[i]), tellwidth = true)
        menu_wt = Menu(fig; options = WEIGHT_OPTIONS, default = default_weight(calibrator[i]), halign = :left, tellwidth = true)
        menu_zoom = Menu(fig; options = string.(0:length(unique(calibrator[i].table.x))), default = "0", halign = :left, tellwidth = true)
        ax = Axis(fig[1, 1]; axis_attrs[i]...)
        sc = scatter!(ax, calibrator[i].table.x, calibrator[i].table.y; get_point_attr(scatter_attrs[i], calibrator[i])...)
        DataInspector(sc)
        xlevel = unique(calibrator[i].table.x)
        xrange = calibrationxrange(xlevel)
        scalefactor = reduce(-, extrema(xlevel)) / reduce(-, extrema(calibrator[i].table.y))
        ln = lines!(ax, xrange.x, predict(calibrator[i].machine, xrange); line_attrs[i]...)
        menu_ps = Menu(fig; options = ["All analytes", "This analyte"], default = "All analytes", tellwidth = true)
        components = Dict(:axis => ax, :scatter => sc, :line => ln)
        menu_components = Menu(fig; options = vcat(collect(keys(components)), [:layout, :header, :cells, :acc, :data]), default = "axis", halign = :left, tellwidth = true)
        button_confirm = Button(fig; label = "confirm", halign = :right, tellwidth = true)    
        textbox_attr = Textbox(fig; placeholder = "attribute", halign = :left)
        textbox_value = Textbox(fig; placeholder = "value (julia code)", tellwidth = true, halign = :left)
        button_show = Button(fig; label = "Show Sample Table", halign = :left)
        menu_filesave = Menu(fig; options = ["Batch", "Layout", "Calibration Data", "Calibration Figure", "Sample Table"], default = "Batch", halign = :left, tellwidth = true)
        button_filesave = Button(fig; label = "Save", tellwidth = true, halign = :left)
        button_filesaveas = Button(fig; label = "Save as", tellwidth = true, halign = :left)
        label_analyte = Label(fig, "Analyte"; tellwidth = true, halign = :left)
        label_message = Label(fig, isnothing(message) ? "" : message; halign = :left, tellwidth = false)
        label_zoom = Label(fig, "Zoom"; tellwidth = true)
        label_type = Label(fig, "Type"; tellwidth = true)
        label_wt = Label(fig, "Weight"; tellwidth = true)
        label_ps = Label(fig, "Layout"; halign = :left, tellwidth = true)
        for x in [label_analyte, menu_analyte, label_lp, label_r2, label_formula, label_zoom, menu_zoom, 
            label_type, menu_type, label_wt, menu_wt, label_ps, menu_ps, menu_components, textbox_attr, button_confirm, textbox_value, 
            button_show, menu_filesave, button_filesave, button_filesaveas, label_message]
            push!(component, x)
        end
        fig[1, 2] = vgrid!(
            hgrid!(label_analyte, menu_analyte; tellwidth = true), 
            label_lp,
            label_formula,
            label_r2,
            hgrid!(label_zoom, menu_zoom; tellwidth = true),
            hgrid!(label_type, menu_type; tellwidth = true), 
            hgrid!(label_wt, menu_wt; tellwidth = true),
            hgrid!(label_ps, menu_ps; tellwidth = true),
            menu_components, 
            textbox_attr,
            hgrid!(textbox_value, button_confirm; tellwidth = true),
            button_show,
            menu_filesave,
            hgrid!(button_filesave, button_filesaveas; tellwidth = true);
            halign = :left,
            tellheight = false
        )
        fig[2, 1] = label_message
        if isnothing(origin) || isnothing(widths)
            xr, yr = calibrationplotrange(calibrator[i], acc_attrs[i], extrema(calibrator[i].table.x))
            limits!(ax, xr, yr)
        else
            limits(ax, zip(origin, origin .+ widths)...)
        end
        table = sampletable(calibrator[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = acc_attrs[i][:lloq_multiplier], dev_acc = acc_attrs[i][:dev_acc])
        body!(table_window, table)
        function static_draw!(calibrator; 
                            data_attr = Dict(:sigdigits => [4, 4, 4, 4], :digits => [nothing, nothing, nothing, nothing]),
                            axis_attr = Dict(),
                            scatter_attr = Dict(),
                            line_attr = Dict(),
                            acc_attr = Dict()
                            )
            label_main = Label(fig, "Calibration Curve"; tellwidth = true, halign = :left)
            label_lp = Label(fig, string(length(unique(calibrator.table.x[calibrator.table.include])), " levels, ", count(calibrator.table.include), " points"); halign = :left, tellwidth = true)
            label_r2 = Label(fig, "R² = $(round(r2(calibrator.machine); sigdigits = data_attr[:sigdigits][4], digits = data_attr[:digits][4]))"; halign = :left, tellwidth = true)
            label_formula = Label(fig, CQA.formula_repr(calibrator; sigdigits = data_attr[:sigdigits][1], digits = data_attr[:digits][1]); halign = :left, tellwidth = true)
            label_type = Label(fig, string("Type: ", default_type(calibrator)); halign = :left, tellwidth = true)
            label_wt = Label(fig, string("Weight: ", default_weight(calibrator)); halign = :left, tellwidth = true)
            label_message = Label(fig, ""; halign = :left, tellwidth = false)
            ax = Axis(fig[1, 1]; axis_attr...)
            sc = scatter!(ax, calibrator.table.x, calibrator.table.y; get_point_attr(scatter_attr, calibrator)...)
            xrange = calibrationxrange(unique(calibrator.table.x))
            ln = lines!(ax, xrange.x, predict(calibrator.machine, xrange); line_attr...)
            fig[1, 2] = vgrid!(
                    label_main, 
                    label_lp,
                    label_formula,
                    label_r2,
                    label_type, 
                    label_wt;
                    halign = :left,
                    tellheight = false
                )
            for x in [label_main, label_lp, label_r2, label_formula, label_type, label_wt, label_message]
                push!(component, x)
            end
            fig[2, 1] = label_message
            xr, yr = calibrationplotrange(calibrator, acc_attr, dynamic_range(calibrator))
            limits!(ax, xr, yr)
            return fig
        end
        function update_label!()
            label_r2.text = "R² = $(round(r2(calibrator[i].machine); sigdigits = data_attrs[i][:sigdigits][4], digits = data_attrs[i][:digits][4]))"
            label_formula.text = CQA.formula_repr(calibrator[i]; sigdigits = data_attrs[i][:sigdigits][1], digits = data_attrs[i][:digits][1])
        end
        function update_table!()
            table = sampletable(calibrator[i], batch.data, batch.method; layout_attr = layout_attrs[i], header_attr = header_attrs[i], cells_attr = cells_attrs[i], lloq_multiplier = acc_attrs[i][:lloq_multiplier], dev_acc = acc_attrs[i][:dev_acc])
            body!(table_window, table)
        end
        function update_fixaxis!(fn...)
            origin = ax.targetlimits[].origin
            widths = ax.targetlimits[].widths
            for f in fn 
                f()
            end
            limits!(ax, zip(origin, origin .+ widths)...)
        end
        function update_sc!(check = false, name = nothing)
            delete!(ax, sc)
            sc = scatter!(ax, calibrator[i].table.x, calibrator[i].table.y; get_point_attr(scatter_attrs[i], calibrator[i])...)
            check && !isnothing(name) && getproperty(sc, name)[]
            DataInspector(sc)
        end
        function update_ax!(component, name, value)
            if length(vectorize(value)) > 1 
                setproperty!(components[component], name, value)
                getproperty(components[component], name)[]
            else
                setproperty!(components[component], name, value) 
                getproperty(components[component], name)[]
            end
        end
        function update_fig!()
            analyze!(batch)
            ln.args[] = (ln.args[][1], predict(calibrator[i].machine, xrange))
            label_lp.text = string(length(unique(calibrator[i].table.x[calibrator[i].table.include])), " levels, ", count(calibrator[i].table.include), " points")
            update_label!()
            update_table!()
            label_message.text = ""
            ask_savebatch = true
        end
        function delete_component!()
            for x in component
                delete!(x)
            end
            empty!(component)
            delete!(ax)
        end
        function redraw!(; message = nothing, origin = ax.targetlimits[].origin, widths = ax.targetlimits[].widths)
            delete_component!()
            draw!(; message, origin, widths)
        end
        on(menu_analyte.selection) do s
            j = findfirst(==(s), analytes)
            if j != i
                i = j
                redraw!(; origin = nothing, widths = nothing)
            end
        end
        on(events(ax).mousebutton) do event
            if event.action == Mouse.press
                plot, id = pick(ax)
                if id != 0 && plot == sc && event.button == Mouse.left
                    ro = calibrator[i].table[id]
                    ids = findall(x -> x.x == ro.x && isapprox(x.y, ro.y), calibrator[i].table)
                    for id in ids
                        calibrator[i].table.include[id] = !calibrator[i].table.include[id]
                    end
                    model_calibrator!(calibrator[i], nothing)
                    update_fixaxis!(update_sc!, update_fig!)
                end
            end
        end
        on(menu_type.selection) do s
            update_model!(batch, analyte_id[i], calibrator[i], s)
            update_fixaxis!(update_fig!)
        end
        on(menu_wt.selection) do s
            update_weight!(batch, analyte_id[i], calibrator[i], s)
            update_fixaxis!(update_fig!)
        end
        zoomstate = false
        on(ax.targetlimits) do s 
            zoomstate || (menu_zoom.i_selected[] = 0)
        end
        on(menu_zoom.selection) do s
            isnothing(s) && return
            zoomstate = true
            si = parse(Int, s)
            if si == 0
                xr, yr = calibrationplotrange(calibrator[i], acc_attrs[i], extrema(calibrator[i].table.x))
                limits!(ax, xr, yr)
            else
                x_value = xlevel[si] 
                id = findall(==(x_value), calibrator[i].table.x)
                y_value = calibrator[i].table.y[id]
                Δy = length(unique(y_value)) == 1 ? abs(0.2 * y_value[1]) : -reduce(-, extrema(y_value))
                yl = extrema(y_value) .+ (-Δy, Δy)
                Δx = Δy * scalefactor
                xl = x_value .+ (-Δx, Δx)
                if isapprox(xl...)
                    xl = x_value .+ (-eps(), eps())
                end
                if isapprox(yl...)
                    yl = y_value .+ (-eps(), eps())
                end
                limits!(ax, xl, yl)
            end
            zoomstate = false
        end
        on(button_confirm.clicks) do s
            label_message.text = ""
            ask_savelayout = true
            ids = menu_ps.selection[] == "All analytes" ? eachindex(analytes) : [i]
            validator = layout_validator(attrs, menu_components.selection[], Symbol(textbox_attr.stored_string[]), eval(Meta.parse(textbox_value.stored_string[])))
            isnothing(validator) && return 
            input_validate!(validator, ids, label_message)
            if validator.component == :data
                try 
                    update_label!()             
                    label_message.text = isempty(label_message.text[]) ? "Calibration Data atributes modified." : string("Calibration Data atributes modified.\n", label_message.text[])
                catch e 
                    attrs[:data] = validator.oldattrs
                    update_label!()             
                    label_message.text = isempty(label_message.text[]) ? repr(e) : string(repr(e), "\n", label_message.text[])
                end
            elseif validator.component in [:layout, :header, :cells, :acc]
                try
                    update_table!()
                    label_message.text = isempty(label_message.text[]) ? "Sample Table atributes modified." : string("Sample Table atributes modified.\n", label_message.text[])
                catch e 
                    attrs[validator.component] = validator.oldattrs
                    update_table!()
                    label_message.text = isempty(label_message.text[]) ? repr(e) : string(repr(e), "\n", label_message.text[])
                end
            elseif validator.component == :scatter
                try 
                    update_fixaxis!(() -> update_sc!(true, validator.name))
                    label_message.text = "Calibration Figure atributes modified."
                catch e 
                    attrs[:scatter] = validator.oldattrs
                    update_fixaxis!(update_sc!)
                    label_message.text = isempty(label_message.text[]) ? repr(e) : string(repr(e), "\n", label_message.text[])
                end
            elseif validator.component in [:line, :axis]
                try
                    update_ax!(validator.component, validator.name, validator.value) 
                    label_message.text = "Calibration Figure atributes modified."
                catch e 
                    attrs[validator.component] = validator.oldattrs
                    update_ax!(validator.component, validator.name, validator.oldattrs[i][validator.name])
                    label_message.text = isempty(label_message.text[]) ? repr(e) : string(repr(e), "\n", label_message.text[])
                end
            end
        end
        on(button_show.clicks) do s
            if !active(table_window) 
                table_window = Window()
                update_table!()
                take!(table_channel)
                put!(table_channel, table_window)
            end
            flashframe(table_window)
        end
        on(button_filesave.clicks) do s
            label_message.text = "Saving..."
            if menu_filesave.selection[] == "Calibration Figure"
                f = joinpath(batchdir[], "ui", "figure")
                mkpath(f)
                for j in eachindex(calibrator)
                    delete_component!()
                    static_draw!(calibrator[j]; 
                        data_attr = data_attrs[j], 
                        axis_attr = axis_attrs[j], 
                        scatter_attr = scatter_attrs[j], 
                        line_attr = line_attrs[j], 
                        acc_attr = acc_attrs[j], 
                    )
                    save(joinpath(f, "$j.png"), fig; update = false)
                end
                redraw!(; message = string("Calibration Figure saved in ", f))
            elseif menu_filesave.selection[] == "Sample Table"
                f = joinpath(batchdir[], "ui", "table")
                mkpath(f)
                sampletable_save(f, calibrator, batch, acc_attrs)
                label_message.text = string("Sample Table saved in ", f)
            elseif menu_filesave.selection[] == "Calibration Data"
                f = joinpath(batchdir[], "ui")
                mkpath(f)
                f = joinpath(f, "data.csv")
                CSV.write(f, calibrationdata(calibrator; data_attrs))         
                label_message.text = string("Calibration Data saved in ", f)
            elseif menu_filesave.selection[] == "Batch"
                label_message.text = "Saving..."
                ChemistryQuantitativeAnalysis.write(batchdir[], batch)
                label_message.text = string("Batch saved in ", batchdir[])
                ask_savebatch = false
            elseif menu_filesave.selection[] == "Layout"
                try 
                    write_batch_attr(batchdir[], attrs)
                    label_message.text = string("Layout saved in ", batchdir[])
                    ask_savelayout = false
                catch e 
                    label_message.text = repr(e)
                end
            end
        end
        on(button_filesaveas.clicks) do s
            if menu_filesave.selection[] == "Layout"
                label_message.text = string("Invalid to save layout independently. Save batch in the desired directory first and then save layout.")
                return 
            end
            delete_component!()
            static_draw!(calibrator[i]; 
                        data_attr = data_attrs[i], 
                        axis_attr = axis_attrs[i], 
                        scatter_attr = scatter_attrs[i], 
                        line_attr = line_attrs[i], 
                        acc_attr = acc_attrs[i], 
                    )
            if menu_filesave.selection[] == "Calibration Figure"
                open_dialog("Save as", nothing; select_folder = true, start_folder = dir[]) do f 
                    if !isempty(f) 
                        mkpath(f) 
                        label_message.text = "Saving..."
                        for j in eachindex(calibrator)
                            delete_component!()
                            static_draw!(calibrator[j]; 
                                data_attr = data_attrs[j], 
                                axis_attr = axis_attrs[j], 
                                scatter_attr = scatter_attrs[j], 
                                line_attr = line_attrs[j], 
                                acc_attr = acc_attrs[j], 
                            )
                            save(joinpath(f, "$j.png"), fig; update = false)
                        end
                    end
                    redraw!(; message = isempty(f) ? "Cancelled" : string("Calibration Figure saved in ", f))
                end
            elseif menu_filesave.selection[] == "Sample Table"
                open_dialog("Save as", nothing; select_folder = true, start_folder = dir[]) do f 
                    if !isempty(f) 
                        mkpath(f)
                        label_message.text = "Saving..."
                        sampletable_save(f, calibrator, batch, acc_attrs)
                    end
                    redraw!(;  message = isempty(f) ? "Cancelled" : string("Sample Table saved in ", f))
                end
            elseif menu_filesave.selection[] == "Calibration Data"
                save_dialog("Save as", nothing, ["*.csv"]; start_folder = dir[]) do f 
                    if !isempty(f)
                        f = endswith(f, ".csv") ? f : string(f, ".csv")
                        filedir = dirname(f)
                        mkpath(filedir)
                        label_message.text = "Saving..."
                        CSV.write(f, calibrationdata(calibrator; data_attrs))         
                    end
                    redraw!(; message = isempty(f) ? "Cancelled" : string("Calibration Data saved in ", f))
                end
            elseif menu_filesave.selection[] == "Batch"
                save_dialog("Save as", nothing, ["*.batch"]; start_folder = dir[]) do f 
                    if !isempty(f)
                        newbatchdir = endswith(f, ".batch") ? f : string(f, ".batch")
                        newdir = dirname(newbatchdir)
                        mkpath(newdir)
                        dir[] = newdir
                        batchdir[] = newbatchdir
                        label_message.text = "Saving..."
                        ChemistryQuantitativeAnalysis.write(batchdir[], batch)    
                        ask_savebatch = false
                    end
                    redraw!(; message = isempty(f) ? "Cancelled" : string("Batch saved in ", batchdir[]))
                end
            end
        end
        return fig
    end
    draw!()
    schedule_main()
end
