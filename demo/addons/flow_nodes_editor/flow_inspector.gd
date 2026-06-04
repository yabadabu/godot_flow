@tool
extends PanelContainer
class_name FlowInspector

signal property_edited(prop_name: String)

const BASE_SETTINGS_PROPS = [
	"random_seed", "inspect_enabled", "debug_enabled", "debug_mode", "debug_scale",
	"debug_bulk", "debug_output", "debug_color", "debug_modulate_by", "title",
	"disabled", "trace", "resource_local_to_scene", "resource_path", "resource_name", "script"
]
const GRAPH_PARAMETER_VALUE_EDITED := "_graph_parameter_value_edited"

var current_node: Node = null
var current_settings: Object = null
var current_target: Object = null
var editor: Control = null
var ui_scale: float = 1.0

var scroll_container: ScrollContainer
var content_vbox: VBoxContainer

func _scaled_font_size(base_size: int) -> int:
	return maxi(1, int(round(base_size * ui_scale)))

func _ready():
	custom_minimum_size.x = 268
	if Engine.is_editor_hint():
		ui_scale = EditorInterface.get_editor_scale()

	# Apply original dark theme panel colors
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b1e28") # #1b1e28 node cards background
	sb.set_border_width_all(0)
	sb.border_width_left = 1
	sb.border_color = Color("252836") # #252836 border/separator
	add_theme_stylebox_override("panel", sb)

	# Create ScrollContainer
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)

	# MarginContainer for spacing inside ScrollContainer
	var margin_container = MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	scroll_container.add_child(margin_container)

	# Create ContentVBox
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(content_vbox)

	edit(null)


func _sync_panel_visibility() -> void:
	var has_content := current_target != null and content_vbox.get_child_count() > 0
	visible = has_content
	scroll_container.visible = has_content


func edit(target_node: Object):
	current_target = target_node
	current_node = null if not target_node is Node else target_node
	current_settings = null

	# Clear existing children in ContentVBox
	for child in content_vbox.get_children():
		child.queue_free()
		content_vbox.remove_child(child)

	if target_node == null:
		_sync_panel_visibility()
		return

	if target_node is GraphFrame:
		_populate_frame_properties(target_node)
	elif target_node is GraphNode:
		if target_node.node_template == "input":
			var editor_instance = target_node.getEditor()
			if editor_instance and editor_instance.current_resource:
				current_settings = editor_instance.current_resource
				_populate_graph_resource_properties(editor_instance.current_resource)
				_populate_graph_resource_outputs(editor_instance.current_resource)
				_sync_panel_visibility()
				return
		elif target_node.node_template == "output":
			var editor_instance = target_node.getEditor()
			if editor_instance and editor_instance.current_resource:
				current_settings = editor_instance.current_resource
				_populate_graph_resource_outputs(editor_instance.current_resource)
				_sync_panel_visibility()
				return
		if "settings" in target_node and target_node.settings != null:
			current_settings = target_node.settings
			_populate_node_properties(target_node, target_node.settings)
		else:
			_populate_generic_node_properties(target_node)
	elif target_node is FlowGraphResource:
		current_settings = target_node
		_populate_graph_resource_properties(target_node)
		_populate_graph_resource_outputs(target_node)
	elif FlowInspectorPropertyPolicy.is_flow_editor_settings_proxy(target_node):
		current_settings = target_node
		_populate_flow_editor_settings(target_node)
	elif target_node is Resource:
		current_settings = target_node
		_populate_generic_resource_properties(target_node)
	_sync_panel_visibility()

func edit_editor_settings(flow_editor):
	var settings_proxy := FlowEditorSettingsProxy.new()
	settings_proxy.sync_from_editor(flow_editor)
	edit(settings_proxy)

func refresh_localized_text() -> void:
	if current_target != null and is_instance_valid(current_target):
		if current_target.has_method("_on_auto_regen_toggled"):
			edit_editor_settings(current_target)
		else:
			edit(current_target)
		return
	edit(null)

func _node_title(node: GraphNode) -> String:
	if node != null and node.has_method("getLocalizedTitle"):
		return str(node.call("getLocalizedTitle"))
	return FlowI18n.tn(node.title)

func _hide_inspector_title_enabled() -> bool:
	if current_target != null and "hide_inspector_title" in current_target:
		return bool(current_target.hide_inspector_title)
	if current_node != null and current_node.has_method("getEditor"):
		var flow_editor = current_node.getEditor()
		if flow_editor and "hide_inspector_title" in flow_editor:
			return bool(flow_editor.hide_inspector_title)
	return false

func _localized_property_label(property_name: String) -> String:
	return FlowInspectorPropertyPolicy.localized_property_label(current_settings, property_name)

func _section_label(expanded: bool, label: String) -> String:
	var prefix := "▼ " if expanded else "▶ "
	return prefix + FlowI18n.t(label)

func _populate_flow_editor_settings(settings_proxy: Object):
	_add_header(FlowI18n.t("Settings"), FlowI18n.t("Flow Editor"))
	_add_native_property_rows(settings_proxy)

func _populate_frame_properties(frame: GraphFrame):
	_add_header(FlowI18n.tn(frame.title), frame.name)

	# Frame Properties Container
	var prop_box = VBoxContainer.new()
	prop_box.add_theme_constant_override("separation", 8)
	content_vbox.add_child(prop_box)

	_add_native_property_by_name(prop_box, frame, "title")
	_add_native_property_by_name(prop_box, frame, "tint_color")
	_add_native_property_by_name(prop_box, frame, "tint_color_enabled")

	var flow_editor: FlowEditor = _find_flow_editor(frame)
	if flow_editor:
		var actions_box := VBoxContainer.new()
		actions_box.add_theme_constant_override("separation", 6)
		content_vbox.add_child(actions_box)
		var add_btn := Button.new()
		add_btn.text = FlowI18n.t("Add Selected Nodes")
		add_btn.pressed.connect(func():
			var added: int = flow_editor.add_selected_nodes_to_comment_frame(frame)
			if flow_editor.has_method("update_status_bar"):
				if added > 0:
					flow_editor.update_status_bar(FlowI18n.t("Added %d nodes to comment") % added)
				else:
					flow_editor.update_status_bar(FlowI18n.t("No nodes added to comment"))
		)
		actions_box.add_child(add_btn)
		var remove_btn := Button.new()
		remove_btn.text = FlowI18n.t("Remove Selected Nodes")
		remove_btn.pressed.connect(func():
			var removed: int = flow_editor.remove_selected_nodes_from_comment_frame(frame)
			if flow_editor.has_method("update_status_bar"):
				if removed > 0:
					flow_editor.update_status_bar(FlowI18n.t("Removed %d nodes from comment") % removed)
				else:
					flow_editor.update_status_bar(FlowI18n.t("No nodes removed from comment"))
		)
		actions_box.add_child(remove_btn)

func _find_flow_editor(from_node: Node) -> FlowEditor:
	var current := from_node
	while current:
		if current is FlowEditor:
			return current as FlowEditor
		current = current.get_parent()
	return null

func _populate_generic_node_properties(node: GraphNode):
	var hide_title := _hide_inspector_title_enabled()
	_add_header(_node_title(node), node.name, not hide_title)

func _populate_node_properties(node: GraphNode, settings: Object):
	var hide_title := _hide_inspector_title_enabled()
	_add_header(_node_title(node), node.name, not hide_title)

	# Build attribute selector lookup: prop_name -> port
	var attr_selector_map := {}
	if settings.has_method("_get_attribute_selector_props"):
		for entry in settings._get_attribute_selector_props():
			attr_selector_map[entry["prop"]] = entry.get("port", 0)

	var variable_selector_props := {}
	if settings.has_method("_get_variable_selector_props"):
		for entry in settings._get_variable_selector_props():
			variable_selector_props[entry["prop"]] = true

	# Type-specific properties container
	var type_box = VBoxContainer.new()
	type_box.add_theme_constant_override("separation", 10)
	content_vbox.add_child(type_box)

	if not hide_title:
		_add_native_property_by_name(type_box, settings, "title")

	# Gather subclass-specific properties
	var props = settings.get_property_list()
	var has_custom_props = false

	for prop in props:
		if prop.name in BASE_SETTINGS_PROPS:
			continue
		if (int(prop.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if settings.has_method("exposeParam") and not settings.exposeParam(prop.name):
			continue

		var ctrl: Control
		if attr_selector_map.has(prop.name):
			ctrl = _create_attribute_selector(node, settings, prop.name, attr_selector_map[prop.name])
		elif variable_selector_props.has(prop.name):
			ctrl = _create_variable_selector(node, settings, prop.name)
		else:
			if _add_native_property_editor(type_box, settings, prop):
				has_custom_props = true
			continue
		if ctrl:
			type_box.add_child(_create_row(_localized_property_label(prop.name), ctrl))
			has_custom_props = true

	if node is FlowNodeBase and node.node_template == "get_variable":
		type_box.add_child(_create_row(FlowI18n.t("Source"), _create_get_variable_source_button(node, settings)))
		has_custom_props = true
	if node is FlowNodeBase and node.node_template == "set_variable":
		_populate_set_variable_get_references(node as FlowNodeBase, settings, type_box)
		has_custom_props = true

	if not has_custom_props:
		var lbl_empty = Label.new()
		lbl_empty.text = FlowI18n.t("No custom settings")
		lbl_empty.add_theme_color_override("font_color", Color("a1a1aa"))
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_box.add_child(lbl_empty)

	# Separator before Common Settings
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_stylebox())
	content_vbox.add_child(sep)

	# Collapsible Common Settings
	var common_header = Button.new()
	common_header.text = _section_label(true, "Common Settings")
	common_header.flat = true
	common_header.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	common_header.add_theme_color_override("font_color", Color("22d3ee")) # Cyan #22d3ee accent
	common_header.add_theme_color_override("font_hover_color", Color.WHITE)
	content_vbox.add_child(common_header)

	var common_container = VBoxContainer.new()
	common_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(common_container)

	common_header.pressed.connect(func():
		common_container.visible = not common_container.visible
		if common_container.visible:
			common_header.text = _section_label(true, "Common Settings")
		else:
			common_header.text = _section_label(false, "Common Settings")
	)

	# Populate Common Settings
	for prop in props:
		if not prop.name in BASE_SETTINGS_PROPS:
			continue
		if prop.name in ["resource_local_to_scene", "resource_path", "resource_name", "script", "title", "disabled", "trace"]:
			continue
		if (int(prop.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if settings.has_method("exposeParam") and not settings.exposeParam(prop.name):
			continue

		_add_native_property_editor(common_container, settings, prop)

	# Override Pins for subgraph nodes
	if node.node_template == "subgraph" and settings is SubgraphNodeSettings and settings.graph:
		_populate_subgraph_overrides(node, settings)

func _populate_subgraph_overrides(node: GraphNode, settings: SubgraphNodeSettings):
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_stylebox())
	content_vbox.add_child(sep)

	var header = Button.new()
	header.text = _section_label(true, "Override Pins")
	header.flat = true
	header.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_color_override("font_color", Color("fbbf24"))  # Yellow for overrides
	header.add_theme_color_override("font_hover_color", Color.WHITE)
	content_vbox.add_child(header)

	var override_container = VBoxContainer.new()
	override_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(override_container)

	header.pressed.connect(func():
		override_container.visible = not override_container.visible
		header.text = _section_label(override_container.visible, "Override Pins")
	)

	for param in settings.graph.in_params:
		if not param:
			continue
		# Create a row with: [Override checkbox] [Param name] [Value control]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Override toggle checkbox
		var checkbox = CheckBox.new()
		checkbox.button_pressed = settings.has_param_override(param.name)
		checkbox.add_theme_font_size_override("font_size", _scaled_font_size(11))

		# Value control based on param type
		var value_ctrl = _create_override_value_control(settings, param)
		if value_ctrl:
			value_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Dim the control when override is not active
			if not settings.has_param_override(param.name):
				value_ctrl.modulate = Color(1, 1, 1, 0.4)

			var captured_param = param
			var captured_ctrl = value_ctrl
			checkbox.toggled.connect(func(pressed: bool):
				if pressed:
					settings.set_param_override(captured_param.name, captured_param.get_default_value())
					captured_ctrl.modulate = Color.WHITE
				else:
					settings.clear_param_override(captured_param.name)
					captured_ctrl.modulate = Color(1, 1, 1, 0.4)
				property_edited.emit("param_overrides")
			)

		row.add_child(checkbox)

		var label = Label.new()
		label.text = param.name
		label.add_theme_font_size_override("font_size", _scaled_font_size(11))
		label.custom_minimum_size.x = 80
		row.add_child(label)

		if value_ctrl:
			row.add_child(value_ctrl)

		override_container.add_child(row)

func _create_override_value_control(settings: SubgraphNodeSettings, param: GraphInputParameter) -> Control:
	var current_val = settings.get_param_value(param)

	match param.data_type:
		FlowData.DataType.Bool:
			var cb = CheckBox.new()
			cb.button_pressed = current_val if current_val is bool else false
			var captured_param = param
			cb.toggled.connect(func(pressed):
				settings.set_param_override(captured_param.name, pressed)
				property_edited.emit("param_overrides")
			)
			return cb
		FlowData.DataType.Int:
			var sb = SpinBox.new()
			sb.min_value = -999999
			sb.max_value = 999999
			sb.step = 1
			sb.value = int(current_val) if current_val != null else 0
			var captured_param = param
			sb.value_changed.connect(func(new_val):
				settings.set_param_override(captured_param.name, int(new_val))
				property_edited.emit("param_overrides")
			)
			return sb
		FlowData.DataType.Float:
			var sb = SpinBox.new()
			sb.min_value = -999999.0
			sb.max_value = 999999.0
			sb.step = 0.01
			sb.value = float(current_val) if current_val != null else 0.0
			var captured_param = param
			sb.value_changed.connect(func(new_val):
				settings.set_param_override(captured_param.name, new_val)
				property_edited.emit("param_overrides")
			)
			return sb
		FlowData.DataType.String:
			var le = LineEdit.new()
			le.text = str(current_val) if current_val != null else ""
			le.add_theme_font_size_override("font_size", _scaled_font_size(11))
			var sb_style := StyleBoxFlat.new()
			sb_style.bg_color = Color("111318")
			sb_style.set_corner_radius_all(3)
			sb_style.content_margin_left = 6
			sb_style.content_margin_right = 6
			le.add_theme_stylebox_override("normal", sb_style)
			var captured_param = param
			le.text_submitted.connect(func(new_text):
				settings.set_param_override(captured_param.name, new_text)
				property_edited.emit("param_overrides")
			)
			le.focus_exited.connect(func():
				var cur = settings.get_param_value(captured_param)
				if str(cur) != le.text:
					settings.set_param_override(captured_param.name, le.text)
					property_edited.emit("param_overrides")
			)
			return le
		FlowData.DataType.Vector:
			var vec_val: Vector3 = current_val if current_val is Vector3 else Vector3.ZERO
			var hbc = HBoxContainer.new()
			hbc.add_theme_constant_override("separation", 4)
			var captured_param = param
			for axis in ["x", "y", "z"]:
				var this_axis = axis
				var sb_axis = SpinBox.new()
				sb_axis.min_value = -999999.0
				sb_axis.max_value = 999999.0
				sb_axis.step = 0.01
				sb_axis.custom_minimum_size.x = 48
				sb_axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if axis == "x":
					sb_axis.value = vec_val.x
				elif axis == "y":
					sb_axis.value = vec_val.y
				else:
					sb_axis.value = vec_val.z
				sb_axis.value_changed.connect(func(new_val):
					var cur_val = settings.get_param_value(captured_param)
					var next_vec: Vector3 = cur_val if cur_val is Vector3 else Vector3.ZERO
					if this_axis == "x":
						next_vec.x = new_val
					elif this_axis == "y":
						next_vec.y = new_val
					else:
						next_vec.z = new_val
					settings.set_param_override(captured_param.name, next_vec)
					property_edited.emit("param_overrides")
				)
				hbc.add_child(sb_axis)
			return hbc
		FlowData.DataType.Resource:
			var res_hbox = HBoxContainer.new()
			var res_lbl = Label.new()
			res_lbl.text = FlowI18n.t("None") if current_val == null else current_val.resource_path.get_file()
			res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			res_lbl.clip_text = true
			res_lbl.add_theme_font_size_override("font_size", _scaled_font_size(11))
			res_hbox.add_child(res_lbl)
			var res_btn = Button.new()
			res_btn.text = "..."
			var captured_param = param
			res_btn.pressed.connect(func():
				var fd = FileDialog.new()
				fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				fd.access = FileDialog.ACCESS_RESOURCES
				fd.add_filter("*.tres,*.res", "Resource Files")
				fd.file_selected.connect(func(path):
					var res = load(path)
					if res:
						settings.set_param_override(captured_param.name, res)
						res_lbl.text = path.get_file()
						property_edited.emit("param_overrides")
					fd.queue_free()
				)
				fd.canceled.connect(func():
					fd.queue_free()
				)
				add_child(fd)
				fd.popup_centered_ratio(0.4)
			)
			res_hbox.add_child(res_btn)
			return res_hbox
	return null

func _add_header(title_text: String, id_text: String, show_title: bool = true):
	# Title bar panel matching #252836
	var header_panel = PanelContainer.new()
	var hb_style = StyleBoxFlat.new()
	hb_style.bg_color = Color("252836") # #252836 node headers background
	hb_style.set_corner_radius_all(4)
	hb_style.content_margin_left = 10
	hb_style.content_margin_right = 10
	hb_style.content_margin_top = 8
	hb_style.content_margin_bottom = 8
	header_panel.add_theme_stylebox_override("panel", hb_style)

	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	header_panel.add_child(header_vbox)

	if show_title and not title_text.is_empty():
		var lbl_title = Label.new()
		lbl_title.text = title_text
		lbl_title.add_theme_font_size_override("font_size", _scaled_font_size(14))
		lbl_title.add_theme_color_override("font_color", Color.WHITE)
		header_vbox.add_child(lbl_title)

	var lbl_id = Label.new()
	lbl_id.text = id_text
	lbl_id.add_theme_font_size_override("font_size", _scaled_font_size(10 if show_title and not title_text.is_empty() else 14))
	lbl_id.add_theme_color_override("font_color", Color("a1a1aa") if show_title and not title_text.is_empty() else Color.WHITE)
	header_vbox.add_child(lbl_id)

	content_vbox.add_child(header_panel)

	# Small space
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	content_vbox.add_child(spacer)

func _create_row(label_text: String, control: Control) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", _scaled_font_size(11))
	lbl.add_theme_color_override("font_color", Color("cbd5e1")) # light gray
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	row.add_child(lbl)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _add_native_property_rows(
	object: Object,
	included: Array = [],
	excluded: Dictionary = {},
) -> FlowNativePropertyRows:
	var rows := FlowNativePropertyRows.new()
	rows.setup(object, included, excluded)
	rows.property_edited.connect(func(prop_name: String):
		property_edited.emit(prop_name)
	)
	if not rows.is_empty():
		content_vbox.add_child(rows)
	return rows

func _add_native_property_editor(parent: VBoxContainer, object: Object, prop: Dictionary) -> bool:
	var property_name := str(prop.name)
	var editor_property := FlowInspectorPropertyPolicy.create_native_property_editor(
		object,
		prop.type,
		property_name,
		prop.hint,
		prop.hint_string,
		prop.usage,
		false,
		FlowInspectorPropertyPolicy.localized_property_label(object, property_name)
	)
	if editor_property == null:
		return false
	editor_property.property_changed.connect(func(
		edited_property: StringName,
		value,
		_field: StringName,
		_changing: bool,
	):
		var edited_property_name := String(edited_property)
		object.set(edited_property_name, value)
		if object is Resource:
			object.emit_changed()
		property_edited.emit(edited_property_name)
	)
	editor_property.multiple_properties_changed.connect(func(properties: PackedStringArray, values: Array):
		var count := mini(properties.size(), values.size())
		for index in range(count):
			var edited_property_name := String(properties[index])
			object.set(edited_property_name, values[index])
			property_edited.emit(edited_property_name)
		if object is Resource:
			object.emit_changed()
	)
	parent.add_child(editor_property)
	return true

func _add_native_property_by_name(parent: VBoxContainer, object: Object, property_name: String) -> bool:
	for prop in object.get_property_list():
		if str(prop.name) == property_name:
			return _add_native_property_editor(parent, object, prop)
	return false

## Creates an attribute selector: OptionButton dropdown populated from upstream
## stream names, with a "(custom...)" option that reveals a text field.
func _create_attribute_selector(node: GraphNode, settings: Object, prop_name: String, port: int) -> Control:
	var current_val := str(settings.get(prop_name))
	var stream_names := _get_input_stream_names(node, port)

	var wrapper = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)

	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", _scaled_font_size(11))
	opt.custom_minimum_size.x = 100

	# Fallback text input for custom attribute names
	var le = LineEdit.new()
	le.text = current_val
	le.placeholder_text = FlowI18n.t("attribute name...")
	le.add_theme_font_size_override("font_size", _scaled_font_size(11))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("111318")
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	le.add_theme_stylebox_override("normal", sb)
	le.visible = false

	# Populate dropdown
	var selected_idx := -1
	var idx := 0
	for sname in stream_names:
		opt.add_item(sname, idx)
		if sname == current_val:
			selected_idx = idx
		idx += 1

	# Add separator and custom option
	var custom_idx := idx
	opt.add_separator()
	opt.add_item(FlowI18n.t("(custom...)"), custom_idx + 1)

	if stream_names.is_empty():
		opt.selected = opt.item_count - 1
		opt.set_item_text(opt.item_count - 1, FlowI18n.t("(no attributes found)"))
		opt.disabled = true
		opt.visible = true
		le.visible = true
	elif selected_idx >= 0:
		opt.selected = selected_idx
		opt.disabled = false
		opt.set_item_text(opt.item_count - 1, FlowI18n.t("(custom...)"))
		opt.visible = true
		le.visible = false
	else:
		opt.selected = opt.item_count - 1
		opt.disabled = false
		opt.set_item_text(opt.item_count - 1, FlowI18n.t("(custom...)"))
		opt.visible = true
		le.visible = true

	opt.item_selected.connect(func(index):
		var item_id = opt.get_item_id(index)
		if item_id == custom_idx + 1:
			# Switch to custom text input
			le.visible = true
			le.grab_focus()
		else:
			var chosen = opt.get_item_text(index)
			le.visible = false
			le.text = chosen
			_on_value_changed(settings, prop_name, chosen)
	)

	le.text_submitted.connect(func(new_text):
		_on_value_changed(settings, prop_name, new_text)
	)
	le.focus_exited.connect(func():
		if str(settings.get(prop_name)) != le.text:
			_on_value_changed(settings, prop_name, le.text)
	)

	wrapper.add_child(opt)
	wrapper.add_child(le)
	return wrapper

func _create_variable_selector(node: GraphNode, settings: Object, prop_name: String) -> Control:
	var current_val := str(settings.get(prop_name))
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	opt.custom_minimum_size.x = 100

	var selected_idx := -1
	var item_idx := 0
	var editor_instance = node.getEditor() if node and node.has_method("getEditor") else null
	var definitions := []
	if editor_instance and editor_instance.has_method("getSetVariableDefinitions"):
		definitions = editor_instance.getSetVariableDefinitions()

	for definition in definitions:
		var variable_name := String(definition.get("name", ""))
		if variable_name.is_empty():
			continue
		opt.add_item(variable_name, item_idx)
		if variable_name == current_val:
			selected_idx = item_idx
		item_idx += 1

	if item_idx == 0:
		opt.add_item(FlowI18n.t("No variables set"), 0)
		opt.selected = 0
		opt.disabled = true
	else:
		opt.disabled = false
		opt.select(selected_idx)

	opt.item_selected.connect(func(index):
		if opt.disabled:
			return
		_on_value_changed(settings, prop_name, opt.get_item_text(index))
		if node and node.has_method("refreshVariableChoices"):
			node.refreshVariableChoices()
	)
	return opt

func _populate_set_variable_get_references(node: FlowNodeBase, settings: Object, parent: VBoxContainer) -> void:
	var variable_name := str(settings.get("variable_name")).strip_edges()
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	var header := Label.new()
	header.text = FlowI18n.t("Get nodes using this variable")
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("a1a1aa"))
	section.add_child(header)
	if variable_name.is_empty():
		var hint := Label.new()
		hint.text = FlowI18n.t("Set a variable name first")
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color("71717a"))
		section.add_child(hint)
		return
	var editor_instance: FlowEditor = null
	if node.has_method("getEditor"):
		editor_instance = node.getEditor() as FlowEditor
	if editor_instance == null or not editor_instance.has_method("getGetVariableNodes"):
		return
	var get_nodes := editor_instance.getGetVariableNodes(variable_name)
	if get_nodes.is_empty():
		var empty := Label.new()
		empty.text = FlowI18n.t("No get nodes use this variable")
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color("71717a"))
		section.add_child(empty)
		return
	for get_node in get_nodes:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_child(row)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		if get_node.has_method("getTitle"):
			btn.text = String(get_node.call("getTitle"))
		else:
			btn.text = String(get_node.name)
		btn.tooltip_text = FlowI18n.t("Pan to this get node without changing selection")
		btn.disabled = not editor_instance.has_method("focusGetVariableNode")
		var target := get_node
		btn.pressed.connect(func():
			if editor_instance and editor_instance.has_method("focusGetVariableNode"):
				editor_instance.focusGetVariableNode(target)
		)
		row.add_child(btn)

func _create_get_variable_source_button(node: GraphNode, settings: Object) -> Button:
	var btn = Button.new()
	btn.text = FlowI18n.t("Locate Set Variable")
	btn.add_theme_font_size_override("font_size", 11)

	var editor_instance = node.getEditor() if node and node.has_method("getEditor") else null
	btn.disabled = editor_instance == null or not editor_instance.has_method("focusSetVariableNode")
	btn.pressed.connect(func():
		var variable_name := str(settings.get("variable_name")).strip_edges()
		if variable_name.is_empty():
			return
		editor_instance.focusSetVariableNode(variable_name)
	)
	return btn

## Gets the stream names available on a node's input at the given port.
## Returns the names from the last-evaluated data (requires Regenerate first).
func _get_input_stream_names(node: GraphNode, port: int) -> PackedStringArray:
	var names := PackedStringArray()
	if not node or not "inputs" in node:
		return names
	if port < 0 or port >= node.inputs.size():
		return names
	var input_data = node.inputs[port]
	if input_data == null or not input_data is FlowData.Data:
		return names
	for sname in input_data.streams.keys():
		names.append(str(sname))
	names.sort()
	return names


func _on_value_changed(obj: Object, prop_name: String, new_val):
	obj.set(prop_name, new_val)
	if obj is Resource:
		obj.emit_changed()
	property_edited.emit(prop_name)

func _create_separator_stylebox() -> StyleBoxLine:
	var sbl = StyleBoxLine.new()
	sbl.color = Color("252836")
	sbl.thickness = 1
	return sbl

func _populate_graph_resource_properties(res: FlowGraphResource) -> void:
	_add_graph_parameters_control(res, "in_params", FlowI18n.t("Graph Inputs"), true)

func _populate_graph_resource_outputs(res: FlowGraphResource) -> void:
	_add_graph_parameters_control(res, "out_params", FlowI18n.t("Graph Outputs"), false)

func _add_graph_parameters_control(
	res: FlowGraphResource,
	prop_name: String,
	title: String,
	include_value: bool,
) -> void:
	var editor := FlowGraphParametersEditor.new()
	editor.setup(res, prop_name, title, include_value)
	editor.property_edited.connect(func(edited_prop_name: String):
		property_edited.emit(edited_prop_name)
	)
	content_vbox.add_child(editor)

func _populate_generic_resource_properties(res: Resource):
	_add_header(res.resource_path.get_file() if res.resource_path != "" else res.get_class(), res.get_class())
	_add_native_property_rows(res)
