@tool
extends "res://addons/flow_nodes_editor/nodes/tags_mutate.gd"

func _init():
	meta_node = {
		"title" : "Delete Tags",
		"settings" : TagsMutateSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Removes one or more tags from FlowData.",
		"aliases" : ["Delete Tags", "Remove Tags"],
		"category" : "Metadata",
	}

# Forces the Remove operation without mutating the shared settings resource
# (writing settings.operation at execute time persisted to disk when the
# settings resource was saved/shared).
func execute(ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = require_input(0, ctx)
	if in_data == null:
		return

	var tags_to_apply = _parse_tags()
	var out_data = in_data.duplicate()
	var filtered := PackedStringArray()
	for t in out_data.tags:
		if not _has_tag(tags_to_apply, t):
			filtered.append(t)
	out_data.tags = filtered
	set_output(0, out_data)
