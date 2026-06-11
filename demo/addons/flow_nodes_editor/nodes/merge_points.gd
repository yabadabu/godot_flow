@tool
extends "res://addons/flow_nodes_editor/nodes/merge.gd"

func _init():
	meta_node = {
		"title" : "Merge Points",
		"settings" : MergeNodeSettings,
		"ins" : [{ "label": "In", "multiple_connections" : true }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Merge", "Merge Points"],
		"category" : "Utility",
		"tooltip" : "Godot-facing alias of Merge for point data.",
	}
