@tool
extends EditorInspectorPlugin

func _can_handle(obj: Object) -> bool:
	return obj is GraphInputParameter

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool):
	if name.begins_with("cte_"):
		var settings := object as GraphInputParameter
		var name_lc = FlowData.DataType.keys()[ settings.data_type ].to_lower()
		if name == "cte_" + name_lc:
			return false
		# Hide the attribute
		return true
	return name != "name" and name != "data_type"
