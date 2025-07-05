@tool
class_name SampleSplineNodeSettings
extends NodeSettings

@export_group("Sample Spline")

@export var uniform_interval : float = 0.2
@export var fill_curve : bool = false
@export var required_meta_bool : StringName

func _init():
	super._init()
	resource_name = "Sample Spline Settings"
