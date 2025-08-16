@tool
extends EditorInspectorPlugin
class_name FlowNodesInspectorPlugin

func _can_handle(object):
	return object is NodeSettings

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	var settings : NodeSettings = object as NodeSettings
	if settings != null:
		return not settings.exposeParam( name )
	return true
