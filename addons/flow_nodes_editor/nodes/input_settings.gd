@tool
class_name InputNodeSettings
extends NodeSettings

@export_group("Input")

@export var name : String

func _init():
	super._init()
	resource_name = "Input"
