@tool
class_name RandomColorNodeSettings
extends NodeSettings

@export_group("Random Color")

@export var out_name : String = "color"
@export var use_palette : bool = true:
	set(value):
		if use_palette != value:
			use_palette = value
			notify_property_list_changed()
@export var palette : Array[Color] = [
	Color(1.0, 0.078, 0.576, 1.0), # Pink
	Color(0.0, 0.749, 1.0, 1.0),   # Cyan
	Color(1.0, 0.843, 0.0, 1.0)    # Yellow
]

@export_range(0.0, 1.0) var hue_min : float = 0.0
@export_range(0.0, 1.0) var hue_max : float = 1.0
@export_range(0.0, 1.0) var sat_min : float = 0.6
@export_range(0.0, 1.0) var sat_max : float = 1.0
@export_range(0.0, 1.0) var val_min : float = 0.6
@export_range(0.0, 1.0) var val_max : float = 1.0

func _init():
	super._init()
	resource_name = "Random Color Settings"

func exposeParam(name : String) -> bool:
	if name == "palette":
		return use_palette
	if name in ["hue_min", "hue_max", "sat_min", "sat_max", "val_min", "val_max"]:
		return not use_palette
	return true
