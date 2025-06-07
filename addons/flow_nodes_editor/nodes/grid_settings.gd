@tool
class_name GridNodeSettings
extends NodeSettings

@export_group("Grid")

@export var x : int = 3
@export var y : int = 3
@export var z : int = 1
@export var step : Vector3 = Vector3( 1.0, 1.0, 1.0 )

func _init():
	super._init()
	resource_name = "Grid Settings"
