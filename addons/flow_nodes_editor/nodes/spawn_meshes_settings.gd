@tool
class_name SpawnMeshesNodeSettings
extends NodeSettings

@export_group("Spawn Meshes")

@export var mesh : Mesh

func _init():
	super._init()
	resource_name = "Spawn Meshes Settings"
