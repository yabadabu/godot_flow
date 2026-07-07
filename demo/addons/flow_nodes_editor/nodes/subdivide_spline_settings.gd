@tool
class_name SubdivideSplineNodeSettings
extends NodeSettings

@export_group("Subdivide Spline")

#@export var grammar_in_attribute := false
@export var grammar : String
@export_subgroup("Input Attributes", "attribute_")
@export var attribute_symbol : String = "symbol"
@export var attribute_length : String = "bounds.z"
@export var attribute_scalable : String = "scalable"
#@export var attribute_grammar : String

func _init():
	super._init()
	resource_name = "Subdivide Spline Settings"
