@tool

## Editor Inspector to show just the parameters we want from a Graph Resource
extends EditorInspectorPlugin

func _can_handle(obj: Object) -> bool:
	return obj is FlowGraphResource

func _parse_property(obj: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool):
	if obj is FlowGraphResource:
		if name == "in_params" or name == "graph_name":
			return false
		return true
	if name == "overrides":
		return true
	# Returning true, meaning we already handled... because we are not, these become invisible
	return false
