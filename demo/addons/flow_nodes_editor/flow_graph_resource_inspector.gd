@tool
extends EditorInspectorPlugin

# Editor Inspector to show just the parameter associated to the Input Type
# So, if the input is defined as float, show only the cte_float member in the inspector

func _can_handle(obj: Object) -> bool:
	return obj is FlowGraphResource # or obj is FlowGraphNode3D

func _parse_property(obj: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool):
	if obj is FlowGraphResource:
		if name == "in_params" or name == "graph_name":
			return false
		return true
	if name == "overrides":
		return true
	#if name == "in_params":
		#return false
	# Returning true, meaning we already handled... because we are not, these become invisible
	return false
