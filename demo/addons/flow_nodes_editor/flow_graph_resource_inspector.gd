@tool
extends EditorInspectorPlugin

# Editor Inspector to show just the parameter associated to the Input Type
# So, if the input is defined as float, show only the cte_float member in the inspector

func _can_handle(obj: Object) -> bool:
	return obj is FlowGraphResource

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool):
	if name == "in_params":
		return false
	# Returning true, meaning we already handled... because we are not, these become invisible
	return true
