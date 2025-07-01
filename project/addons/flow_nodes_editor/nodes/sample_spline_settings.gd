@tool
class_name SampleSplineNodeSettings
extends NodeSettings

@export_group("Sample Spline")

@export var uniform_interval : float = 0.2

func _init():
	super._init()
	resource_name = "Sample Spline Settings"
