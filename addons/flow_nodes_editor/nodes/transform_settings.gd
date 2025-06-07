@tool
class_name TransformNodeSettings
extends NodeBaseSettings

@export_group("Transform")

@export var trans : Transform3D = Transform3D(Basis.IDENTITY, Vector3(0,0,1))

func _init():
	super._init()
	resource_name = "Transform Settings"
