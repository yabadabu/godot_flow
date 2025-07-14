@tool
class_name DistanceNodeSettings
extends NodeSettings

@export_group("Distance")

@export var max_distance : float = 0.0

var HiddenFromThisPoint := true
@export var out_name : String = "distance"
@export var in_nameA : String = FlowData.AttrPosition
@export var in_nameB : String = FlowData.AttrPosition

func _init():
	super._init()
	resource_name = "Distance Settings"
