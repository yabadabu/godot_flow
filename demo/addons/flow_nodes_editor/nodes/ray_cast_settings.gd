@tool
class_name RayCastNodeSettings
extends NodeSettings

@export_group("RayCast")

@export var dir : Vector3 = Vector3(0,0,-1)
@export var max_distance : float = 1e3

func _init():
	super._init()
	resource_name = "RayCast Settings"
