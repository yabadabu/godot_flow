@tool
extends "res://addons/flow_nodes_editor/nodes/clip_points_by_polygon.gd"

const PolygonOperationSettings = preload("res://addons/flow_nodes_editor/nodes/clip_points_by_polygon_settings.gd")

func _init():
	meta_node = {
		"title" : "Polygon Operation",
		"settings" : PolygonOperationSettings,
		"ins" : [{ "label" : "Points" }, { "label" : "Polygon" }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Polygon Clip", "Clip Points By Polygon"],
		"category" : "Filter",
		"tooltip" : "Alias of Clip Points By Polygon: keeps points inside (or outside) polygons built from the Polygon input, a spline stream, or a scene NodePath.\nNo union/intersect/difference modes — clipping only. Falls back to the settings NodePath when the Polygon input yields no usable polygon.",
	}
