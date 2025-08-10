@tool
class_name SampleMeshNodeSettings
extends NodeSettings

@export_group("Sample Mesh")

@export var num_samples : int = 100

func _init():
	super._init()
	resource_name = "Sample Mesh Settings"
