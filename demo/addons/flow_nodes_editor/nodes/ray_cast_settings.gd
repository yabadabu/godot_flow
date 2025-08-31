@tool
class_name RayCastNodeSettings
extends NodeSettings

@export_group("RayCast")

@export var dir : Vector3 = Vector3.DOWN
@export var max_distance : float = 1e3

@export var from_attribute : String = "position"

@export var out_result_attribute : String = "hit"
@export var out_position_attribute : String = "position"
@export var out_rotation_attribute : String = "rotation"

func _init():
	super._init()
	resource_name = "RayCast Settings"
