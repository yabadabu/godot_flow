@tool
extends "res://addons/flow_nodes_editor/nodes/attribute_filter_range.gd"

const PointFilterRangeNodeSettings = preload("res://addons/flow_nodes_editor/nodes/point_filter_range_settings.gd")

func _init():
	meta_node = {
		"title" : "Point Filter Range",
		"settings" : PointFilterRangeNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Inside" }, { "label" : "Outside" }],
		"aliases" : ["Point Filter"],
		"category" : "Filter",
		"tooltip" : "Point-focused alias of Attribute Filter Range (defaults to position.X).\nNumeric range mode coerces Vectors to their length and Colors to their RGB average; enable 'String Match Mode' to filter by comma-separated string values instead.",
	}
