@tool
class_name BoundsModifierNodeSettings
extends NodeSettings

@export_group("Bounds Modifier")

enum eMode { Set, Add, Multiply, AddPadding }
			
@export var mode: eMode = eMode.Set:
	set(value):
		if mode != value:
			mode = value
			notify_property_list_changed()
			
@export var bounds_min: Vector3 = -Vector3.ONE * 0.5
@export var bounds_max: Vector3 = Vector3.ONE * 0.5
@export var padding: Vector3 = Vector3.ONE
@export var uniform_scale : float = 1.0

func _init():
	super._init()
	resource_name = "Bounds Modifier Settings"

func exposeParam( name : String ) -> bool:
	if name == "padding":
		return mode == eMode.AddPadding
	if name == "bounds_min" or name == "bounds_max":
		return mode != eMode.AddPadding
	return true
