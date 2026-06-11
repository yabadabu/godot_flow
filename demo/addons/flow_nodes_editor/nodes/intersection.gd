@tool
extends "res://addons/flow_nodes_editor/nodes/difference.gd"

func _init():
	meta_node = {
		"title" : "Intersection",
		"settings" : DifferenceNodeSettings,
		"ins" : [{ "label": "In A" }, { "label": "In B" }],
		"outs" : [{ "label" : "Out" }],
		"hide_inputs" : true,
		"aliases" : ["Intersection"],
		"category" : "Spatial",
		"tooltip" : "Returns points in A that overlap points in B (Intersection alias).",
	}

func getTitle() -> String:
	return "Intersection"

func execute(ctx : FlowData.EvaluationContext):
	# Force the Intersection operation WITHOUT mutating the saved settings
	# resource (which would dirty/rewrite the shared .tres and make the
	# inspector's operation dropdown a lie). A duplicated settings resource is
	# swapped in only for the duration of the shared implementation.
	var saved_settings = settings
	var forced_settings = settings.duplicate()
	forced_settings.operation = DifferenceNodeSettings.eOperation.Intersection
	settings = forced_settings
	super.execute(ctx)
	settings = saved_settings
