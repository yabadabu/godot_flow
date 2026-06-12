@tool
extends RefCounted
class_name FlowInspectorPropertyPolicy

const DEFAULT_EDITOR_META := &"_flow_creating_default_editor"
const EDITOR_SETTING_HIDE_RESOURCE_BUILTIN_ROWS := "addons/flow_nodes_editor/hide_resource_builtin_rows"
const HIDDEN_RESOURCE_PROPERTIES := {
	"resource_local_to_scene": true,
	"resource_path": true,
	"resource_scene_unique_id": true,
	"resource_name": true,
	"script": true,
}


static func add_localized_property_editor(
	inspector_plugin: EditorInspectorPlugin,
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags,
	wide: bool,
	label: String,
) -> bool:
	var editor := create_native_property_editor(
		object,
		type,
		name,
		hint_type,
		hint_string,
		usage_flags,
		wide,
		label
	)
	if editor == null:
		return false
	inspector_plugin.add_property_editor(name, editor, false, label)
	return true


static func create_native_property_editor(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags,
	wide: bool,
	label: String,
) -> EditorProperty:
	var had_meta := false
	var previous_meta = null
	if object != null:
		had_meta = object.has_meta(DEFAULT_EDITOR_META)
		previous_meta = object.get_meta(DEFAULT_EDITOR_META) if had_meta else null
		object.set_meta(DEFAULT_EDITOR_META, true)

	var editor := EditorInspector.instantiate_property_editor(
		object,
		type,
		name,
		hint_type,
		hint_string,
		usage_flags,
		wide
	)

	if object != null:
		if had_meta:
			object.set_meta(DEFAULT_EDITOR_META, previous_meta)
		elif object.has_meta(DEFAULT_EDITOR_META):
			object.remove_meta(DEFAULT_EDITOR_META)

	if editor == null:
		return null
	editor.set_object_and_property(object, name)
	editor.label = label
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.update_property()
	return editor


static func is_creating_default_editor(object: Object) -> bool:
	return object != null and object.has_meta(DEFAULT_EDITOR_META)


static func is_flow_editor_settings_proxy(object: Object) -> bool:
	return (
		object != null
		and object.has_method("is_flow_editor_settings_proxy")
		and bool(object.call("is_flow_editor_settings_proxy"))
	)


static func is_hidden_resource_property(property_name: String) -> bool:
	return HIDDEN_RESOURCE_PROPERTIES.has(property_name)


static func should_hide_resource_builtin_rows() -> bool:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings == null:
		return true
	if not editor_settings.has_setting(EDITOR_SETTING_HIDE_RESOURCE_BUILTIN_ROWS):
		return true
	return bool(editor_settings.get_setting(EDITOR_SETTING_HIDE_RESOURCE_BUILTIN_ROWS))


static func should_show_property(
	object: Object,
	property_name: String,
	usage_flags,
	require_storage: bool = true,
	skip_resource_builtin_rows: bool = true,
) -> bool:
	if skip_resource_builtin_rows and should_hide_resource_builtin_rows() and is_hidden_resource_property(property_name):
		return false
	if require_storage and (int(usage_flags) & PROPERTY_USAGE_STORAGE) == 0:
		return false
	if is_flow_editor_settings_proxy(object):
		return (
			object.has_method("has_flow_editor_setting_property")
			and bool(object.call("has_flow_editor_setting_property", property_name))
		)
	var settings := object as NodeSettings
	if settings != null and not settings.exposeParam(property_name):
		return false
	return true


static func localized_property_label(object: Object, property_name: String) -> String:
	if is_flow_editor_settings_proxy(object) and object.has_method("get_flow_editor_setting_label"):
		return String(object.call("get_flow_editor_setting_label", property_name))
	if object is NodeSettings:
		return FlowI18n.tn(format_label(property_name))
	return FlowI18n.t(format_label(property_name))


static func format_label(property_name: String) -> String:
	return property_name.capitalize()
