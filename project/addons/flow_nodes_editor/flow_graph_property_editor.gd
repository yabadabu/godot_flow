@tool
extends EditorProperty
#class_name FlowGraphPropertyEditor
#
#var edit_button: Button
#var current_resource: FlowGraphResource
#
#func _init():
	## Create the UI
	#edit_button = Button.new()
	#edit_button.text = "Edit Flow Graph"
	#edit_button.pressed.connect(_on_edit_pressed)
	#add_child(edit_button)
	#
	## Handle resource assignment
	#var resource_picker = EditorResourcePicker.new()
	#resource_picker.base_type = "FlowGraphResource"
	#resource_picker.resource_changed.connect(_on_resource_changed)
	#add_child(resource_picker)
#
#func _on_resource_changed(resource: Resource):
	#print( "Graph resource changed...")
	#current_resource = resource as FlowGraphResource
	#edit_button.disabled = current_resource == null
	#emit_changed(get_edited_property(), current_resource)
#
#func _on_edit_pressed():
	#if current_resource:
		## Open your custom graph editor
		##FlowGraphEditorWindow.open_editor(current_resource)
		#print( "Editing...", current_resource)
#
#func _update_property():
	#var new_value = get_edited_object()[get_edited_property()]
	#if new_value != current_resource:
		#current_resource = new_value
		#edit_button.disabled = current_resource == null
		#print( "Graph resource edit...")
