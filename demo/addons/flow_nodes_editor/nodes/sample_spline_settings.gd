@tool
class_name SampleSplineNodeSettings
extends NodeSettings

@export_group("Sample Spline")

@export var uniform_interval : float = 0.2
@export var fill_curve : bool = false:
	set( new_value ):
		fill_curve = new_value
		notify_property_list_changed()
		
@export var adjust_to_borders : bool = true
@export var sample_segments_centers : bool = false
@export var distance_attribute : String = "distance"

func _init():
	super._init()
	resource_name = "Sample Spline Settings"

func exposeParam( name : String ) -> bool:
	if name == "sample_segments_centers":
		return not fill_curve
	return true
