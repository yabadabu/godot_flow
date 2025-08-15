@tool
class_name SamplePointsNodeSettings
extends NodeSettings

@export_group("Sample Points")

@export var sampling_distance : float = 0.2
@export var max_x : int = 32
@export var max_y : int = 32
@export var max_z : int = 32
@export var new_size_factor : float = 1.0

func _init():
	super._init()
	resource_name = "Sample Points Settings"
