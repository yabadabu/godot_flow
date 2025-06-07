@tool
class_name NodeSettings
extends Resource

enum eDebugMode {
	EXTENDS,
	ABSOLUTE,
}

@export_group("Common Settings")
@export var rng_seed: int = 12345

@export var inspect_enabled: bool = false

@export var debug_enabled: bool = false
@export var debug_mode : eDebugMode = eDebugMode.EXTENDS
@export var debug_scale : float = 1.0

# Add any other common properties here
@export var title: String = ""
@export var enabled: bool = true

func _init():
	# Set default values when resource is created
	resource_name = "Node Settings"
	rng_seed = randi()
