@tool
extends FlowNodeBase

const AttributeRenameNodeSettings = preload("res://addons/flow_nodes_editor/nodes/attribute_rename_settings.gd")

func _init():
	meta_node = {
		"title" : "Attribute Rename",
		"settings" : AttributeRenameNodeSettings,
		"category" : "Metadata",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Renames one attribute/stream while preserving its type and values.\nSubstreams like position.X can't be renamed",
	}

func getTitle() -> String:
	return "%s -> %s" % [ settings.from_name, settings.to_name ] 

func execute(_ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input not found")
		return
	var out_data : FlowData.Data = in_data.duplicate()
	var err_msg = out_data.renameStream( settings.from_name, settings.to_name, settings.overwrite_existing )
	if err_msg:
		setError(err_msg)
	set_output(0, out_data)
