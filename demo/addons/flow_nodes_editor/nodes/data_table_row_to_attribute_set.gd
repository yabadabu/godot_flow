@tool
extends FlowNodeBase

const DataTableRowToAttributeSetSettings = preload("res://addons/flow_nodes_editor/nodes/data_table_row_to_attribute_set_settings.gd")

func _init():
	meta_node = {
		"title" : "Data Table Row To Attribute Set",
		"settings" : DataTableRowToAttributeSetSettings,
		"ins" : [{ "label" : "Rows" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Extracts one or more table rows into an attribute-set stream.",
		"aliases" : ["Data Table Row To Attribute Set"],
		"category" : "Metadata",
	}

func _value_matches(value, target : String) -> bool:
	var lhs := str(value)
	var rhs := target
	if not settings.case_sensitive:
		lhs = lhs.to_lower()
		rhs = rhs.to_lower()
	return lhs == rhs

func execute(_ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = require_input(0, _ctx, "Input rows")
	if in_data == null:
		return
	var in_size := in_data.size()
	if in_size == 0:
		set_output(0, in_data.duplicate())
		return

	var indices := PackedInt32Array()
	if settings.selection_mode == DataTableRowToAttributeSetSettings.eSelectionMode.RowIndex:
		if settings.row_index < 0 or settings.row_index >= in_size:
			# Keep the schema/tags of the input (consistent with the MatchAttribute
			# empty-result path) instead of emitting a fresh schemaless Data
			push_warning("Data Table Row To Attribute Set: row index %d is out of range (0..%d)" % [settings.row_index, in_size - 1])
			set_output(0, in_data.filter(PackedInt32Array()))
			return
		indices.append(settings.row_index)
	else:
		var stream = in_data.findStream(settings.key_attribute)
		if stream == null:
			setError("Key attribute '%s' not found" % settings.key_attribute)
			return
		for i in range(stream.container.size()):
			if _value_matches(stream.container[i], settings.key_value):
				indices.append(i)
				if not settings.include_all_matches:
					break

	set_output(0, in_data.filter(indices))
