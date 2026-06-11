@tool
class_name AttributeNoiseNodeSettings
extends NodeSettings

@export_group("Attribute Noise")

enum eMode {
	Set,
	Minimum,
	Maximum,
	Add,
	Multiply,
}

@export var target_attribute : String = "density":
	set(value):
		target_attribute = value.strip_edges()
		emit_changed()

@export var mode : eMode = eMode.Set:
	set(value):
		mode = value
		emit_changed()

@export var noise_min : float = 0.0:
	set(value):
		noise_min = value
		emit_changed()

@export var noise_max : float = 1.0:
	set(value):
		noise_max = value
		emit_changed()

@export var invert_source : bool = false:
	set(value):
		invert_source = value
		emit_changed()

@export var clamp_result : bool = true:
	set(value):
		clamp_result = value
		emit_changed()

func _init():
	super._init()
	resource_name = "Attribute Noise Settings"

func _get_attribute_selector_props() -> Array[Dictionary]:
	return [
		{ "prop": "target_attribute", "port": 0 },
	]
