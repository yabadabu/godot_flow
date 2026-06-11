@tool
extends "res://addons/flow_nodes_editor/nodes/tags_mutate.gd"

func _init():
	meta_node = {
		"title" : "Replace Tags",
		"settings" : TagsMutateSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Replace Tags"],
		"category" : "Metadata",
		"tooltip" : "Replaces all FlowData tags with the provided set.\nThe 'operation' setting is ignored — this node always replaces.",
	}

func execute(ctx : FlowData.EvaluationContext):
	# Always Replace — implemented here instead of forcing settings.operation,
	# so execute() never mutates the shared/saved settings resource.
	var in_data : FlowData.Data = require_input(0, ctx)
	if in_data == null:
		return
	var out_data = in_data.duplicate()
	out_data.tags = _parse_tags()
	set_output(0, out_data)
