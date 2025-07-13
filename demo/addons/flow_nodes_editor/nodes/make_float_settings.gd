@tool
class_name MakeFloatNodeSettings
extends NodeSettings

@export_group("Make Float")

@export var value : float

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "Float"

func _init():
	super._init()
	resource_name = "Make Float Settings"
