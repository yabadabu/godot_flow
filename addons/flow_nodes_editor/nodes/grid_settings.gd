@tool
class_name GridNodeSettings
extends NodeSettings

@export_group("Grid")

@export_range( 0, 50 ) var x : int = 3
@export_range( 0, 50 ) var y : int = 1
@export_range( 0, 50 ) var z : int = 3
@export var step : Vector3 = Vector3( 1.0, 1.0, 1.0 )

func _init():
	super._init()
	resource_name = "Grid Settings"
