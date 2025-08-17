@tool
class_name MathOpNodeSettings
extends NodeSettings

@export_group("Math Op")

enum eOperation {
	Add,
	Substract,
	Multiply,
	Divide,
	Negate,			# 4
	Absolute,
	Saturate,
	Floor,
	FloorAsInt,
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

@export var operation : eOperation = eOperation.Add:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
@export var in_nameA : String = "@last"
@export var in_nameB : String = "@last"
@export var out_name : String

func _init():
	super._init()
	resource_name = "Math Op"

func isSingleArgument( ) -> bool:
	return operation == eOperation.Absolute or \
	   operation == eOperation.Floor or \
	   operation == eOperation.FloorAsInt or \
	   operation == eOperation.Negate or \
	   operation == eOperation.Saturate or \
	   operation == eOperation.OneMinus or \
	   operation == eOperation.Sign or \
	   operation == eOperation.Sqrt or \
	   false

func exposeParam( name : String ) -> bool:
	if name == "in_nameB":
		return not isSingleArgument()
	return true
