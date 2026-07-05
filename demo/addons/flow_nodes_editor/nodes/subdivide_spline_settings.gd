@tool
class_name SubdivideSplineNodeSettings
extends NodeSettings

@export_group("Subdivide Spline")

#@export var grammar_in_attribute := false
@export var grammar : String
#@export var attribute_grammar : String

func _init():
	super._init()
	resource_name = "Subdivide Spline Settings"
