@tool
extends FlowNodeBase

const GetLoopIndexNodeSettings = preload("res://addons/flow_nodes_editor/nodes/get_loop_index_settings.gd")

func _init():
	meta_node = {
		"title" : "Get Loop Index",
		"settings" : GetLoopIndexNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Get Loop Index"],
		"category" : "Utility",
		"tooltip" : "Writes a sequential index attribute for each incoming point (start_index..start_index+N-1).\nNote: unlike UE's Get Loop Index (which returns the Loop subgraph iteration), this enumerates points — closer to UE's $Index property.",
	}

func execute(ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var out_name = settings.out_name.strip_edges()
	if out_name == "":
		setError("Output name can't be empty")
		return

	var num_points = in_data.size()
	var out_indices := PackedInt32Array()
	out_indices.resize(num_points)
	for i in range(num_points):
		out_indices[i] = settings.start_index + i

	var out_data = in_data.duplicate()
	var err = out_data.registerStream(out_name, out_indices, FlowData.DataType.Int)
	if err:
		setError(err)
		return

	set_output(0, out_data)
