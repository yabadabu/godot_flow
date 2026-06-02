@tool
class_name FlowEditorChrome
extends RefCounted

## Toolbar + tab row (styles, signals, i18n). Does not touch graph / comment code.

const INITIALIZED_META := &"flow_editor_chrome_initialized"


class Refs:
	var host: Control
	var tab_bar: TabBar
	var toolbar_hbox: HBoxContainer
	var open_graph_button: Button
	var expand_graph_button: Button

	func is_valid() -> bool:
		return host != null and tab_bar != null and toolbar_hbox != null


static func is_valid_layout(host: Control) -> bool:
	return host.has_node("VBoxContainer/TabBarPanel/TabBarRow/TabBar")


static func clear_initialized(host: Control) -> void:
	if host.has_meta(INITIALIZED_META):
		host.remove_meta(INITIALIZED_META)


static func setup(refs: Refs) -> void:
	if not refs.is_valid():
		return
	if refs.host.has_meta(INITIALIZED_META):
		apply_translations(refs)
		return
	enforce_vbox_order(refs)
	connect_signals(refs)
	apply_styles(refs)
	apply_translations(refs)
	refs.host.set_meta(INITIALIZED_META, true)


static func enforce_vbox_order(refs: Refs) -> void:
	var vbox := refs.host.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	var legacy_breadcrumb := vbox.get_node_or_null("BreadcrumbPanel")
	if legacy_breadcrumb:
		legacy_breadcrumb.free()
	var legacy_open := refs.toolbar_hbox.get_node_or_null("ButtonOpenGraph")
	if legacy_open:
		legacy_open.free()
	var order := [
		"TabBarPanel",
		"ScrollContainer",
		"VSplitContainer",
		"StatusPanel",
	]
	for i in order.size():
		var node := vbox.get_node_or_null(order[i])
		if node:
			vbox.move_child(node, i)


static func connect_signals(refs: Refs) -> void:
	var host := refs.host
	if refs.tab_bar:
		if not refs.tab_bar.tab_changed.is_connected(host._on_tab_changed):
			refs.tab_bar.tab_changed.connect(host._on_tab_changed)
		if not refs.tab_bar.tab_close_pressed.is_connected(host._on_tab_close_pressed):
			refs.tab_bar.tab_close_pressed.connect(host._on_tab_close_pressed)
	if refs.open_graph_button and not refs.open_graph_button.pressed.is_connected(host._on_button_open_pressed):
		refs.open_graph_button.pressed.connect(host._on_button_open_pressed)
	_connect_pressed(refs, "ButtonSave", host._on_button_save_pressed)
	_connect_pressed(refs, "ButtonReload", host._on_button_reload_pressed)
	_connect_pressed(refs, "ButtonAnalyze", host._on_button_analyze_pressed)
	_connect_pressed(refs, "ButtonRegenerate", host._on_button_regenerate_pressed)
	_connect_pressed(refs, "ButtonInputs", host._on_button_inputs_pressed)
	_connect_pressed(refs, "ButtonSettings", host._on_button_settings_pressed)
	_connect_toggled(refs, "AutoRegen", host._on_auto_regen_toggled)
	_connect_toggled(refs, "CheckColorNodes", host._on_color_nodes_toggled)
	var inputs_button := refs.toolbar_hbox.get_node_or_null("ButtonInputs") as Button
	if inputs_button:
		inputs_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if refs.expand_graph_button and not refs.expand_graph_button.pressed.is_connected(host._on_button_expand_graph_pressed):
		refs.expand_graph_button.pressed.connect(host._on_button_expand_graph_pressed)


static func _connect_pressed(refs: Refs, node_name: String, callback: Callable) -> void:
	var button := refs.toolbar_hbox.get_node_or_null(node_name) as Button
	if button and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


static func _connect_toggled(refs: Refs, node_name: String, callback: Callable) -> void:
	var checkbox := refs.toolbar_hbox.get_node_or_null(node_name) as CheckBox
	if checkbox and not checkbox.toggled.is_connected(callback):
		checkbox.toggled.connect(callback)


static func apply_styles(refs: Refs) -> void:
	var vbox := refs.host.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	var tab_panel := vbox.get_node_or_null("TabBarPanel") as PanelContainer
	if tab_panel:
		var tab_sb := StyleBoxFlat.new()
		tab_sb.bg_color = Color("0e1016")
		tab_sb.content_margin_left = 4
		tab_sb.content_margin_right = 4
		tab_sb.content_margin_top = 2
		tab_sb.content_margin_bottom = 0
		tab_panel.add_theme_stylebox_override("panel", tab_sb)
	var toolbar_container := vbox.get_node_or_null("ScrollContainer") as ScrollContainer
	if toolbar_container:
		var sb_tb := StyleBoxFlat.new()
		sb_tb.bg_color = Color("171a24")
		sb_tb.content_margin_left = 8
		sb_tb.content_margin_right = 8
		sb_tb.content_margin_top = 6
		sb_tb.content_margin_bottom = 6
		toolbar_container.add_theme_stylebox_override("panel", sb_tb)
	var status_panel := vbox.get_node_or_null("StatusPanel") as PanelContainer
	if status_panel:
		var status_sb := StyleBoxFlat.new()
		status_sb.bg_color = Color("0a0c12")
		status_sb.border_width_top = 1
		status_sb.border_color = Color(1.0, 1.0, 1.0, 0.04)
		status_sb.content_margin_left = 12
		status_sb.content_margin_right = 12
		status_sb.content_margin_top = 4
		status_sb.content_margin_bottom = 4
		status_panel.add_theme_stylebox_override("panel", status_sb)
	for child in refs.toolbar_hbox.get_children():
		if child is Button:
			if child.name == "ButtonRegenerate":
				_style_regenerate_button(child as Button)
			else:
				_style_toolbar_button(child as Button)
	if refs.open_graph_button:
		_style_toolbar_button(refs.open_graph_button)
	if refs.expand_graph_button:
		_style_toolbar_button(refs.expand_graph_button)


static func apply_translations(refs: Refs) -> void:
	if not refs.is_valid():
		return
	FlowI18n.reload_locale_files()
	var text_by_name := {
		"ButtonAnalyze": "Analyze",
		"ButtonReload": "Reload",
		"ButtonInputs": "Inputs",
		"ButtonSave": "Save Resource",
		"AutoRegen": "Auto Generate",
		"CheckColorNodes": "Color Nodes",
		"ButtonRegenerate": "Regenerate",
		"ButtonExpandGraph": "Expand",
		"ButtonSettings": "Settings",
	}
	for node_name in text_by_name:
		var control := _get_control(refs, node_name)
		if control is Button:
			(control as Button).text = FlowI18n.t(String(text_by_name[node_name]))
		elif control is Label:
			(control as Label).text = FlowI18n.t(String(text_by_name[node_name]))
	var tooltip_by_name := {
		"ButtonAnalyze": "Inspect selected node raw data (A)",
		"ButtonExpandGraph": "Float and Maximize Graph Panel",
	}
	for node_name in tooltip_by_name:
		var control := _get_control(refs, node_name)
		if control:
			control.tooltip_text = FlowI18n.t(String(tooltip_by_name[node_name]))
	if refs.open_graph_button:
		refs.open_graph_button.text = "+"
		refs.open_graph_button.tooltip_text = FlowI18n.t("Open a FlowGraph resource")


static func _get_control(refs: Refs, node_name: String) -> Control:
	var control := refs.toolbar_hbox.get_node_or_null(node_name) as Control
	if control:
		return control
	if node_name == "ButtonOpenGraph" and refs.open_graph_button:
		return refs.open_graph_button
	if node_name == "ButtonExpandGraph" and refs.expand_graph_button:
		return refs.expand_graph_button
	return null


static func _style_toolbar_button(btn: Button) -> void:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	sb_normal.set_border_width_all(1)
	sb_normal.border_color = Color(1.0, 1.0, 1.0, 0.1)
	sb_normal.set_corner_radius_all(3)
	sb_normal.content_margin_left = 10
	sb_normal.content_margin_right = 10
	sb_normal.content_margin_top = 4
	sb_normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb_normal)
	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(1.0, 1.0, 1.0, 0.09)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(1.0, 1.0, 1.0, 0.02)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", Color("cdd0dc"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color("a1a1aa"))


static func _style_regenerate_button(btn: Button) -> void:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color("1b1e28")
	sb_normal.set_border_width_all(1)
	sb_normal.border_color = Color("22d3ee")
	sb_normal.set_corner_radius_all(3)
	sb_normal.content_margin_left = 10
	sb_normal.content_margin_right = 10
	sb_normal.content_margin_top = 4
	sb_normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb_normal)
	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color("252836")
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color("111318")
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", Color("22d3ee"))
	btn.add_theme_color_override("font_hover_color", Color("22d3ee"))
	btn.add_theme_color_override("font_pressed_color", Color("22d3ee"))
