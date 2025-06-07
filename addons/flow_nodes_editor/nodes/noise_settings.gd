@tool
class_name NoiseNodeSettings
extends NodeSettings

@export_group("Noise")

@export var scale : float = 1.0
@export var out_attribute_name : String = "density"

func _init():
	super._init()
	resource_name = "Noise Settings"
