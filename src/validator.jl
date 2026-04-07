function data_validator!(data_attr)
    @assert data_attr[:digits] isa Vector 
    @assert length(data_attr[:digits]) == 4 
    @assert data_attr[:sigdigits] isa Vector 
    @assert length(data_attr[:sigdigits]) == 4
    default_digits!(data_attr)
end

function acc_validator(acc_attr)
    @assert acc_attr[:dev_acc] isa Real 
    @assert acc_attr[:dev_acc] >= 0 
    @assert acc_attr[:lloq_multiplier] isa Real 
    @assert acc_attr[:lloq_multiplier] >= 0 
end

getvalfn(::Val{:data}) = data_validator!
getvalfn(::Val{:acc}) = acc_validator
getvalfn(::Val) = nothing

layout_validator(attrs, component, name, value) = isnothing(component) ? nothing : (; component, name, value, targetattrs = attrs[component], oldattrs = deepcopy(attrs[component]))

function input_validate!(validator, ids, label_message)
    cattrs = validator.targetattrs
    oattrs = validator.oldattrs
    valfn = getvalfn(Val(validator.component))
    if isnothing(valfn)
        for j in ids
            cattrs[j][validator.name] = validator.value
        end
    else
        for j in ids
            cattrs[j][validator.name] = validator.value
            try 
                valfn(cattrs[j])
            catch e
                cattrs[j][validator.name] = oattrs[j][validator.name]
                label_message.text = repr(e)
            end
        end
    end
end