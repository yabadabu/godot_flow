@tool
class_name SubdivideSplineNodeSettings
extends NodeSettings

@export_group("Subdivide Spline")

enum eFitBehaviour {
	AlignLeft,
	Autoscale,
	Centered,
	AlignRight,
	Interspace
}

#@export var grammar_in_attribute := false
@export var grammar_as_attribute : bool = false:
	set(value):
		grammar_as_attribute = value
		notify_property_list_changed()
		
@export var grammar : String
@export var fit_behaviour : eFitBehaviour = eFitBehaviour.Autoscale
@export_subgroup("Input Attributes", "attribute_")
@export var attribute_symbol : String = "symbol"
@export var attribute_length : String = "bounds.z"
@export var attribute_scalable : String = "scalable"
@export var attribute_grammar : String = "grammar"

@export_range(0.0, 10.0, 0.01, "or_greater")var curve_offset_start : float = 0.0
@export_range(0.0, 10.0, 0.01, "or_greater")var curve_offset_end : float = 0.0
#@export var attribute_grammar : String

func _init():
	super._init()
	resource_name = "Subdivide Spline Settings"
	
func exposeParam( name : String ) -> bool:
	if name == "grammar" or name == "attribute_grammar":
		return grammar_as_attribute == ( name == "attribute_grammar" )
	return true
