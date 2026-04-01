@tool
class_name RelaxNodeSettings
extends NodeSettings

@export_group("Relax")

@export var num_iterations := 1
@export var strength := 0.5

func _init():
	super._init()
	resource_name = "Relax Settings"
