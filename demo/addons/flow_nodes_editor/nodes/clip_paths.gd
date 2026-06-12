@tool
extends "res://addons/flow_nodes_editor/nodes/clip_points_by_polygon.gd"

const ClipPathsSettings = preload("res://addons/flow_nodes_editor/nodes/clip_points_by_polygon_settings.gd")

func _init():
	meta_node = {
		"title" : "Clip Paths",
		"settings" : ClipPathsSettings,
		"ins" : [{ "label" : "Points" }, { "label" : "Paths" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Alias of Clip Points By Polygon with path-style naming.\nClips a point set against polygons built from Path3D splines (no direct UE equivalent;\nthe closest UE workflow is Difference against a spline shape).",
		"aliases" : ["Clip Points"],
		"category" : "Spatial",
	}
