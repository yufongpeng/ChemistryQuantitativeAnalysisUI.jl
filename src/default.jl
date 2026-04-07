# const TYPE_OPTIONS = ["Linear (origin)", "Linear", "Quadratic (origin)", "Quadratic", "Logarithmic", "Exponential", "Power"]
const TYPE_OBJECTS = [
    ProportionalCalibrator,
    LinearCalibrator,
    QuadraticOriginCalibrator,
    QuadraticCalibrator,
    LogarithmicCalibrator,
    ExponentialCalibrator,
    PowerCalibrator
]
_human_name(::Type{CalibrationModel{T}}) where T = CQA.human_name(T())
const TYPE_OPTIONS = [_human_name(T) for T in TYPE_OBJECTS]
default_type(cal::ExternalCalibrator) = default_type(cal.model)
default_type(::CalibrationModel{T}) where T = CQA.human_name(T())
# default_type(::LinearCalibrator) = "Linear"
# default_type(::QuadraticOriginCalibrator) = "Quadratic (origin)"
# default_type(::QuadraticCalibrator) = "Quadratic"
# default_type(::LogarithmicCalibrator) = "Logarithmic"
# default_type(::ExponentialCalibrator) = "Exponential"
# default_type(::PowerCalibrator) = "Power"

function update_model!(batch::Batch, analyte_id, calibrator, x::String)
    j = findfirst(==(x), TYPE_OPTIONS)
    j = isnothing(j) ? 2 : j
    model = TYPE_OBJECTS[j]
    model_calibrator!(batch, analyte_id, calibrator; model)
end

# const WEIGHT_OPTIONS = ["1", "1/√x", "1/√y", "1/x", "1/y", "1/x²", "1/y²", "1/√(x+y)", "1/(x+y)", "1/(x+y)²", "1/√ln(x)", "1/√ln(y)", "1/ln(x)", "1/ln(y)", "1/ln(x)²", "1/ln(y)²", "1/√eˣ", "1/√eʸ", "1/eˣ", "1/eʸ", "1/e²ˣ", "1/e²ʸ"]
const WEIGHT_OBJECTS = [
    ConstWeight(),
    RootXWeight(),
    RootYWeight(),
    XWeight(),
    YWeight(),
    SqXWeight(),
    SqYWeight(),
    RootXYWeight(),
    XYWeight(),
    SqXYWeight(),
    RootLogXWeight(),
    RootLogYWeight(),
    LogXWeight(),
    LogYWeight(),
    SqLogXWeight(),
    SqLogYWeight(),
    RootExpXWeight(),
    RootExpYWeight(),
    ExpXWeight(),
    ExpYWeight(),
    SqExpXWeight(),
    SqExpYWeight()
]

WEIGHT_OPTIONS = CQA.human_name.(WEIGHT_OBJECTS)
default_weight(cal::ExternalCalibrator) = CQA.human_name(cal.model.weight)

function update_weight!(batch::Batch, analyte_id, calibrator, x::String)
    j = findfirst(==(x), WEIGHT_OPTIONS)
    j = isnothing(j) ? 1 : j
    weight = WEIGHT_OBJECTS[j]
    model_calibrator!(batch, analyte_id, calibrator; weight)
end