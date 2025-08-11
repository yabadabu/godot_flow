@tool
class_name MathOpNodeSettings
extends NodeSettings

@export_group("Math Op")

enum eOperation {
	Add,
	Substract,
	Multiply,
	Divide,
	Negate,
	Absolute,
	Saturate,
	Floor,
	FloorAsInt,
	Set,
	Modulo,
	ModuloInt,
	Frac,
	Max,
	Min,
	OneMinus,
	Pow,
	Round,
	Sign,
	Sqrt,
}

@export var operation : eOperation = eOperation.Add
@export var in_nameA : String = "@last"
@export var in_nameB : String = "@last"
@export var out_name : String

func _init():
	super._init()
	resource_name = "Math Op"
