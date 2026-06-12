@tool
class_name MakeBoundsNodeSettings
extends NodeSettings

@export_group("Make Bounds")
@export var size: Vector3 = Vector3(48.0, 1.0, 48.0):
	set(value):
		size = value
		emit_changed()
@export var center: Vector3 = Vector3.ZERO:
	set(value):
		center = value
		emit_changed()

func _init():
	super._init()
	resource_name = "Make Bounds Settings"
