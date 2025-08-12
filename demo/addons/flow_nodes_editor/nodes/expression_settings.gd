@tool
class_name ExpressionNodeSettings
extends NodeSettings

@export_group("Expression")

@export var expression : String
@export var out_name : String = "expr"
@export var expose_arrays : bool = false
@export var args : Dictionary = {}

func _init():
	super._init()
	resource_name = "Expression"
