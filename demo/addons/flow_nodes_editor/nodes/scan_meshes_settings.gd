@tool
class_name ScanMeshesNodeSettings
extends NodeSettings

@export_group("Scan Meshes")

@export var group_name : String
@export var required_meta_bool : StringName

func _init():
	super._init()
	resource_name = "Scan Meshes Settings"
