@tool
extends EditorInspectorPlugin
class_name FlowNodesInspectorPlugin

func _can_handle(object):
	return object is FlowNodeBase

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	var node : FlowNodeBase = object as FlowNodeBase
	if node != null:
		# name property should ot be modified by the user
		if name == "name" or name.begins_with( "resource_" ):
			return true
		return not node.exposeParam( name )
	return true
