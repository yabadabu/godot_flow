@tool
class_name TransformNodeSettings
extends NodeSettings

@export_group("Transform")

@export var offset_min := Vector3(0,0,0)
@export var offset_max := Vector3(0,0,0)
@export var rotation_min := Vector3(0,0,0)
@export var rotation_max := Vector3(0,0,0)
@export var scale_min := Vector3(1,1,1)
@export var scale_max := Vector3(1,1,1)
@export var uniform_scale := true

func _init():
	super._init()
	resource_name = "Transform Settings"
