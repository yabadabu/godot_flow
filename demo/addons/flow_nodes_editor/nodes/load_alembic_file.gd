@tool
extends "res://addons/flow_nodes_editor/nodes/points_from_imported_scene.gd"

const LoadAlembicFileSettings = preload("res://addons/flow_nodes_editor/nodes/points_from_imported_scene_settings.gd")

func _init():
	meta_node = {
		"title" : "Load Alembic File",
		"settings" : LoadAlembicFileSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Load Alembic File"],
		"category" : "Input",
		"tooltip" : "UE naming alias of Points From Imported Scene.\nNote: Godot cannot import .abc (Alembic) files natively — point this at an imported PackedScene or Mesh resource instead; one point is emitted per MeshInstance3D.",
	}
