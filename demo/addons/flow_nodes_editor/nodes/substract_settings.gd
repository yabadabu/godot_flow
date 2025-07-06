@tool
class_name SubstractSettings
extends NodeSettings

@export_group("Substract")

enum eOperation {
	A_Minus_B,
	A_Intersection_B,
	#A_Union_B,
}

@export var operation : eOperation = eOperation.A_Minus_B

func _init():
	super._init()
	resource_name = "Substract"
