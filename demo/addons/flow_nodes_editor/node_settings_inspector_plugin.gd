@tool
extends EditorInspectorPlugin
class_name FlowNodesInspectorPlugin

func _can_handle(object):
	return object is FlowNodeBase

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	var node : FlowNodeBase = object as FlowNodeBase
	if node != null:
		return not node.exposeParam( name )
	return true
