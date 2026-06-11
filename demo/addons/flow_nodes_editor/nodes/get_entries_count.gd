@tool
extends "res://addons/flow_nodes_editor/nodes/size.gd"

func _init():
	meta_node = {
		"title" : "Get Entries Count",
		"settings" : SizeNodeSettings,
		"ins" : [{ "label" : "In"}],
		"outs" : [{ "label" : "Count", "data_type" : FlowData.DataType.Int }],
		"aliases" : ["Entries Count"],
		"category" : "Utility",
		"tooltip" : "Returns the number of entries in the input data (same behavior as Get Data Count / Get Points Count).",
	}

func execute( ctx : FlowData.EvaluationContext ):
	if require_input(0, ctx, "Input 'In'") == null:
		return
	super.execute(ctx)
