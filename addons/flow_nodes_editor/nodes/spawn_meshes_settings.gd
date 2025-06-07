@tool
class_name SpawnMeshesNodeSettings
extends NodeSettings

@export_group("Spawn Meshes")

@export var mesh : Mesh = preload( "res://addons/flow_nodes_editor/resources/unit_cube.tres" )

func _init():
	super._init()
	resource_name = "Spawn Meshes Settings"
