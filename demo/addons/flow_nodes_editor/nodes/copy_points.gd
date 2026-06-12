@tool
extends "res://addons/flow_nodes_editor/nodes/copy.gd"

func _init():
	meta_node = {
		"title" : "Copy Points",
		"settings" : CopyNodeSettings,
		"ins" : [{ "label": "Source" }, { "label": "Targets" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Alias of Copy for point data (UE: Copy Points).\nUse SourceToTargets mode to place one source point per target point.",
		"aliases" : ["Copy Points", "Copy Every Point"],
		"category" : "Spatial",
	}
