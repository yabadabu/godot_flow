@tool
class_name SpawnMeshesNodeSettings
extends NodeBaseSettings

@export_group("Spawn Meshes")

@export var trans : Transform3D = Transform3D(Basis.IDENTITY, Vector3(0,0,1))

func _init():
	super._init()
	resource_name = "Spawn Meshes Settings"
