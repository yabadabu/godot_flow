@tool
extends "res://addons/flow_nodes_editor/nodes/tags_mutate.gd"

func _init():
	meta_node = {
		"title" : "Add Tags",
		"settings" : TagsMutateSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Adds one or more tags to FlowData.",
		"aliases" : ["Add Tags"],
		"category" : "Metadata",
	}

# Forces the Add operation without mutating the shared settings resource
# (writing settings.operation at execute time persisted to disk when the
# settings resource was saved/shared).
func execute(ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = require_input(0, ctx)
	if in_data == null:
		return

	var tags_to_apply = _parse_tags()
	var out_data = in_data.duplicate()
	var curr = out_data.tags.duplicate()
	for t in tags_to_apply:
		if not _has_tag(curr, t):
			curr.append(t)
	out_data.tags = curr
	set_output(0, out_data)
