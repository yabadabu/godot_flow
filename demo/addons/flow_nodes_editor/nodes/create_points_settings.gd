@tool
class_name CreatePointsNodeSettings
extends NodeSettings

@export_group("Create Points")

@export var positions: PackedVector3Array
@export var rotations: PackedVector3Array
@export var sizes:     PackedVector3Array

func _init():
	super._init()
	resource_name = "Create Points Settings"
