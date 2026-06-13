@tool
class_name InputNodeSettings
extends NodeSettings

@export_group("Input")

@export var name : String = "in_val"

func _init():
	super._init()
	resource_name = "Input"
