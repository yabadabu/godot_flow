@tool
class_name SpawnMeshesNodeSettings
extends NodeSettings

@export_group("Spawn Meshes")

@export var trans : Transform3D = Transform3D(Basis.IDENTITY, Vector3(0,0,1))
@export var mesh : Mesh

func _init():
	super._init()
	resource_name = "Spawn Meshes Settings"
