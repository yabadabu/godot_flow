@tool
class_name NodeSettings
extends Resource

# Base class for the settings of all nodes
# Each concrete node implmenets it's own NodeSettings derived class with the 
# arguments that can be tweaked

enum eDebugMode {
	EXTENDS,
	ABSOLUTE,
}

@export_group("Common Settings")
@export var random_seed: int = 12345

@export var inspect_enabled: bool = false

@export var debug_enabled: bool = false
@export var debug_mode : eDebugMode = eDebugMode.EXTENDS
@export var debug_scale : float = 1.0
@export var debug_bulk: int = 0
@export var debug_output: int = 0

@export var debug_color : Color = Color.WHITE
@export var debug_modulate_by : String

# Add any other common properties here
@export var title: String = ""
@export var disabled: bool = false
@export var trace: bool = false

func _init():
	# Set default values when resource is created
	resource_name = "Node Settings"
	# Stable default seed: UE PCG graphs are deterministic by default, so a
	# fresh node must produce the same result every time. Per-point seeds
	# (FlowData.point_seed) decorrelate nodes that share this default.
	# Seeds stored in saved .tres files are unaffected.
	random_seed = 12345

func exposeParam( name : String ):
	return true

## Override in subclasses to declare which String properties are attribute selectors.
## Each entry: { "prop": "property_name", "port": input_port_index }
## The inspector will render these as dropdowns populated from the input data's stream names.
func _get_attribute_selector_props() -> Array[Dictionary]:
	return []
