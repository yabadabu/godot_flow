@tool
class_name SelectNodeSettings
extends NodeSettings

@export_group("Select")

@export_range(0.0, 1.0) var ratio : float = 0.2

func _init():
	super._init()
	resource_name = "Select Settings"
