@tool
extends VBoxContainer
class_name FlowNativePropertyRows

signal property_edited(prop_name: String)

var edited_object: Object
var include_properties: Array[String] = []
var exclude_properties := {}
var require_storage := true
var skip_resource_builtin_rows := true
var _property_editors: Array[EditorProperty] = []


func setup(
	object: Object,
	included: Array = [],
	excluded: Dictionary = {},
	require_storage_props: bool = true,
	skip_hidden_resource_rows: bool = true,
) -> void:
	edited_object = object
	include_properties = _string_array(included)
	exclude_properties = excluded.duplicate()
	require_storage = require_storage_props
	skip_resource_builtin_rows = skip_hidden_resource_rows
	_rebuild()


func is_empty() -> bool:
	return get_child_count() == 0


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_property_editors.clear()

	if edited_object == null:
		return

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	var properties := edited_object.get_property_list()
	var property_by_name := {}
	for prop in properties:
		property_by_name[str(prop.name)] = prop

	if include_properties.is_empty():
		for prop in properties:
			_add_property_if_visible(prop)
		return

	for property_name in include_properties:
		if property_by_name.has(property_name):
			_add_property_if_visible(property_by_name[property_name])


func _add_property_if_visible(prop: Dictionary) -> void:
	var property_name := str(prop.name)
	if exclude_properties.has(property_name):
		return
	if not FlowInspectorPropertyPolicy.should_show_property(
		edited_object,
		property_name,
		prop.usage,
		require_storage,
		skip_resource_builtin_rows
	):
		return

	var editor := FlowInspectorPropertyPolicy.create_native_property_editor(
		edited_object,
		prop.type,
		property_name,
		prop.hint,
		prop.hint_string,
		prop.usage,
		false,
		FlowInspectorPropertyPolicy.localized_property_label(edited_object, property_name)
	)
	if editor == null:
		return
	editor.property_changed.connect(_on_property_changed)
	editor.multiple_properties_changed.connect(_on_multiple_properties_changed)
	_property_editors.append(editor)
	add_child(editor)


func _on_property_changed(
	property: StringName,
	value,
	_field: StringName,
	_changing: bool,
) -> void:
	if edited_object == null or not is_instance_valid(edited_object):
		return
	var property_name := String(property)
	edited_object.set(property_name, value)
	if edited_object is Resource:
		edited_object.emit_changed()
	property_edited.emit(property_name)


func _on_multiple_properties_changed(properties: PackedStringArray, values: Array) -> void:
	if edited_object == null or not is_instance_valid(edited_object):
		return
	var count := mini(properties.size(), values.size())
	for index in range(count):
		var property_name := String(properties[index])
		edited_object.set(property_name, values[index])
		property_edited.emit(property_name)
	if edited_object is Resource:
		edited_object.emit_changed()


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
