@tool
class_name CopyNodeSettings
extends NodeSettings

@export_group("Copy")

@export var num_copies := 1
@export var translation : Vector3 = Vector3.ZERO
@export var rotation : Vector3 = Vector3.ZERO
@export var generate_copy_id : String

func _init():
	super._init()
	resource_name = "Copy Settings"
