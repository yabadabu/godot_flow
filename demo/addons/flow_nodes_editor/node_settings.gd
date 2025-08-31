@tool
class_name NodeSettings
extends Resource

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
	random_seed = randi()

func exposeParam( name : String ):
	return true
