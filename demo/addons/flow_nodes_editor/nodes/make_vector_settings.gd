@tool
class_name MakeVectorNodeSettings
extends NodeSettings

@export_group("Make Vector")

@export var x : float
@export var y : float
@export var z : float

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "Vector"

func _init():
	super._init()
	resource_name = "Make Vector Settings"
