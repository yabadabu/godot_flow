@tool
extends "res://addons/flow_nodes_editor/nodes/size.gd"

func _init():
	meta_node = {
		"title" : "Get Data Count",
		"settings" : SizeNodeSettings,
		"ins" : [{ "label" : "In"}],
		"outs" : [{ "label" : "Count", "data_type" : FlowData.DataType.Int }],
		"aliases" : ["Data Count"],
		"category" : "Utility",
		"tooltip" : "Returns the number of entries in the input data.\nNote: UE's Data Count counts data items in a collection; here every input is a single data, so this returns its entry/point count (same as Get Entries Count / Get Points Count).",
	}

func execute( ctx : FlowData.EvaluationContext ):
	if require_input(0, ctx, "Input 'In'") == null:
		return
	super.execute(ctx)
