@tool
extends EditorInspectorPlugin

# Editor Inspector to show just the parameter associated to the Input Type
# So, if the input is defined as float, show only the cte_float member in the inspector

func _can_handle(obj: Object) -> bool:
	return obj is GraphInputParameter

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool):
	
	# Always display the name
	if name == "name" or name == "is_constant":
		return false
	
	var settings := object as GraphInputParameter
	if settings:
		if settings.is_constant:
			if name.begins_with("cte_"):
				var name_lc = FlowData.DataType.keys()[ settings.data_type ].to_lower()
				if name == "cte_" + name_lc:
					return false
				# Hide the attribute
				return true
			return name != "data_type"
	
	# Everything else is hidden
	return true
