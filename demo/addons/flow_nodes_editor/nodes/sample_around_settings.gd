@tool
class_name SampleAroundNodeSettings
extends NodeSettings

@export_group("Sample Around")

@export var radius : float = 1.0
@export var max_points : int = 100

func _init():
	super._init()
	resource_name = "Sample Around Settings"
