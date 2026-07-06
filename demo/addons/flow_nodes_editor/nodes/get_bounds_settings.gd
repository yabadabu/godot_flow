@tool
class_name GetBoundsNodeSettings
extends NodeSettings

@export_group("Get Bounds")

@export var attribute_name : String = "@auto"

func _init():
	super._init()
	resource_name = "Get Bounds Settings"
