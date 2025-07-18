@tool
class_name ReduceNodeSettings
extends NodeSettings

@export_group("Reduce")

var HiddenFromThisPoint := true

@export var in_name : String
@export var out_prefix : String

func _init():
	super._init()
	resource_name = "Reduce Settings"
