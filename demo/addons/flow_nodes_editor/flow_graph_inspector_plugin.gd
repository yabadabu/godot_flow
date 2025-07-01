@tool
extends EditorInspectorPlugin
#class_name FlowGraphInspectorPlugin
#
#func _can_handle(object):
	## Handle FlowNode3D objects that have a FlowGraphResource
	#return object is FlowGraphNode3D
#
#func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	## Intercept the 'graph' property specifically
	#if name == "graph" and type == TYPE_OBJECT:
		## Create custom property editor
		##var property_editor = FlowGraphPropertyEditor.new()
		##add_property_editor(name, property_editor)
		##var resource_picker = EditorResourcePicker.new()
		##resource_picker.base_type = "FlowGraphResource"
		##resource_picker.resource_changed.connect(_on_resource_changed)
		##add_property_editor( name, resource_picker )
		#var property_editor = FlowGraphPropertyEditor.new()
		#add_property_editor(name, property_editor)
		#return true
	#return false
#
##func _on_resource_changed(resource: Resource):
	##var curr_resource = resource as FlowGraphResource
	##print( "New resource changed...", curr_resource)
	##if curr_resource.nodes.size() == 0:
		##curr_resource.nodes.resize(1)
		##curr_resource.nodes[0] = MathOpNodeSettings.new()
		##print( "added a fake node...", curr_resource)
	#
