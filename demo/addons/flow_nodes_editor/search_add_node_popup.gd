@tool
extends PanelContainer
class_name SearchAddNodePopup

signal node_selected(template_name: String)
signal action_selected(action_id: int)
signal input_selected(input_idx: int)
signal output_selected(output_idx: int)
signal redirect_selected(redirect_id: StringName)
signal on_closed()

var recently_used: Array[String] = [] # Ordered list of recently used template names (most recent first)
const MAX_RECENT : int = 8

@onready var search_text: LineEdit = %SearchText
@onready var categories: VBoxContainer = %Categories
@onready var search_results: VBoxContainer = %SearchResults
@onready var categories_column: Control = categories.get_parent()

var current_node_types: Dictionary = {}
var current_inputs: Array = []
var current_actions: Array = []
var current_redirectors: Array = []
var nodes_by_category: Dictionary = {}
var category_buttons: Dictionary = {}
var compatible_template_names: Array = []
var current_category := ""
var show_inputs_category := false

const RECENTS_CATEGORY := "Recents"
const INPUTS_CATEGORY := "Inputs"
const ACTIONS_CATEGORY := "Actions"
const REDIRECTORS_CATEGORY := "Redirectors"
const ACTION_ADD_NEW_INPUT := 1
const ACTION_COLLAPSE_TO_SUBGRAPH := 2
const ACTION_CREATE_REDIRECTOR := 3
const MIN_POPUP_SIZE := Vector2i(360, 240)
const CATEGORY_ROW_HEIGHT := 30
const POPUP_VERTICAL_PADDING := 58

func _ready():
	visible = false
	set_process_input(true)
	
func appearAt( new_screen_position : Vector2 ):
	var parent_control := get_parent() as Control
	if parent_control:
		position = new_screen_position - parent_control.get_screen_position()
	else:
		position = new_screen_position
	show()
	move_to_front()
	
func setup( node_types : Dictionary, p_inputs: Array, _p_outputs: Array, required_input_type : FlowData.DataType, required_output_type : FlowData.DataType, actions: Array = [], redirectors: Array = [] ):
	print( "invoking menu popup setup... %d %d" % [ required_input_type, required_output_type ])
	current_node_types = node_types
	current_inputs = p_inputs
	current_actions = actions
	current_redirectors = redirectors
	if not search_text.text_changed.is_connected(_on_search_text_changed):
		search_text.text_changed.connect(_on_search_text_changed)
	search_text.text = ""
	categories_column.visible = true
	_clear_options()
	_populate_categories(node_types, required_input_type, required_output_type)
	search_text.grab_focus()
	size.x = 220
	size.y = 420
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _input(event : InputEvent):
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide()
			on_closed.emit()
			return
		if event.keycode == KEY_ENTER:
			if search_results.get_child_count() > 0:
				var b = search_results.get_child(0) as Button
				if b:
					b.pressed.emit()
			return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if not _is_position_over_interactive_content(mouse_event.position):
			hide()
			on_closed.emit()

func _is_position_over_interactive_content(global_position : Vector2) -> bool:
	if search_text.get_global_rect().has_point(global_position):
		return true
	if categories.get_global_rect().has_point(global_position):
		return true
	if search_results.get_global_rect().has_point(global_position):
		return true
	return false

func _clear_options():
	nodes_by_category.clear()
	category_buttons.clear()
	compatible_template_names.clear()
	current_category = ""
	show_inputs_category = false
	for child in categories.get_children():
		categories.remove_child(child)
		child.queue_free()
	for child in search_results.get_children():
		search_results.remove_child(child)
		child.queue_free()

func _populate_categories(node_types : Dictionary, required_input_type : FlowData.DataType, required_output_type : FlowData.DataType):
	print( "Populating %d" % required_input_type)
	for template_name in node_types.keys():
		var node_meta = node_types[template_name]
		if not node_meta.get("auto_register", true):
			continue
		if not _is_compatible(node_meta, required_input_type, required_output_type):
			continue
		compatible_template_names.append(template_name)
		var category : String = _get_category( node_meta )
		if not nodes_by_category.has(category):
			nodes_by_category[category] = []
		nodes_by_category[category].append(template_name)

	show_inputs_category = required_input_type == FlowData.DataType.Invalid
	var category_names := _get_visible_category_names()
	for category_name in category_names:
		_add_category_button(str(category_name))

	_fit_height_to_categories(category_names.size())
	if not category_names.is_empty():
		_show_category(str(category_names[0]))

func _get_visible_category_names() -> Array:
	var category_names := nodes_by_category.keys()
	category_names.erase(RECENTS_CATEGORY)
	category_names.sort()
	var recent_template_names := _get_recent_template_names()
	if not recent_template_names.is_empty():
		nodes_by_category[RECENTS_CATEGORY] = recent_template_names
		category_names.push_front(RECENTS_CATEGORY)
	if show_inputs_category:
		category_names.push_front(INPUTS_CATEGORY)
	if not current_actions.is_empty():
		category_names.push_front(ACTIONS_CATEGORY)
	if not current_redirectors.is_empty():
		category_names.push_front(REDIRECTORS_CATEGORY)
	return category_names

func _get_recent_template_names() -> Array[String]:
	var valid_recent_template_names: Array[String] = []
	for template_name in recently_used:
		if not current_node_types.has(template_name):
			continue
		if not compatible_template_names.has(template_name):
			continue
		valid_recent_template_names.append(template_name)
	return valid_recent_template_names

func _on_search_text_changed(new_text : String):
	var query := new_text.strip_edges()
	if query == "":
		categories_column.visible = true
		var category_names := _get_visible_category_names()
		if not category_names.is_empty():
			_show_category(str(category_names[0]))
		else:
			_clear_results()
		return

	categories_column.visible = false
	_show_search_results(query)

func _add_category_button(category_name : String):
	var category_button := Button.new()
	category_button.text = category_name
	category_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	category_button.toggle_mode = true
	category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_category_button_style(category_button, category_name)
	category_button.pressed.connect(_show_category.bind(category_name))
	category_button.mouse_entered.connect(_show_category.bind(category_name))
	categories.add_child(category_button)
	category_buttons[category_name] = category_button

func _show_category(category_name : String):
	current_category = category_name
	for key in category_buttons.keys():
		var category_button : Button = category_buttons[key]
		category_button.button_pressed = key == current_category

	_clear_results()
	if category_name == INPUTS_CATEGORY:
		_show_inputs()
		return
	if category_name == ACTIONS_CATEGORY:
		_show_actions()
		return
	if category_name == REDIRECTORS_CATEGORY:
		_show_redirectors()
		return

	var template_names : Array = nodes_by_category.get(category_name, [])
	if category_name != RECENTS_CATEGORY:
		template_names.sort_custom(func(a, b):
			return current_node_types[a].get("title", str(a)) < current_node_types[b].get("title", str(b))
		)
	for template_name in template_names:
		if template_name.begins_with("input_"):
			continue
		var node_meta = current_node_types[template_name]
		var node_category := _get_category(node_meta)
		var node_button := Button.new()
		node_button.text = node_meta.get("title", str(template_name))
		node_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(node_button, node_category)
		node_button.pressed.connect(_select_node.bind(template_name))
		if node_meta.has("tooltip"):
			node_button.tooltip_text = node_meta.tooltip
		search_results.add_child(node_button)

func _show_inputs():
	for input_idx in range(current_inputs.size()):
		var input = current_inputs[input_idx]
		var input_button := Button.new()
		input_button.text = FlowNodeBase.editorDisplayName(input.name)
		input_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		input_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(input_button, INPUTS_CATEGORY)
		input_button.pressed.connect(_select_input.bind(input_idx))
		search_results.add_child(input_button)

	var add_button := Button.new()
	add_button.text = "Add New Input..."
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_category_button_style(add_button, INPUTS_CATEGORY)
	add_button.pressed.connect(_select_action.bind(ACTION_ADD_NEW_INPUT))
	search_results.add_child(add_button)

func _show_actions():
	for action in current_actions:
		var action_button := Button.new()
		action_button.text = action.get("label", "Action")
		action_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(action_button, ACTIONS_CATEGORY)
		action_button.pressed.connect(_select_action.bind(action.id))
		if action.has("tooltip"):
			action_button.tooltip_text = action.tooltip
		search_results.add_child(action_button)

func _show_redirectors():
	for definition: FlowGraphRedirect in current_redirectors:
		if not definition:
			continue
		var redirect_button := Button.new()
		redirect_button.text = definition.name
		redirect_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		redirect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(redirect_button, REDIRECTORS_CATEGORY)
		redirect_button.pressed.connect(
			_select_redirect.bind(definition.ensureId())
		)
		search_results.add_child(redirect_button)

func _show_search_results(query : String):
	_clear_results()

	var matches := []
	for template_name in compatible_template_names:
		var score := _get_search_score(template_name, query)
		if score > 0:
			matches.append({
				"template_name": template_name,
				"score": score,
			})

	matches.sort_custom(func(a, b):
		if a.score != b.score:
			return a.score > b.score
		var a_template_name : String = a.template_name
		var b_template_name : String = b.template_name
		var a_meta : Dictionary = current_node_types[a_template_name]
		var b_meta : Dictionary = current_node_types[b_template_name]
		var a_label := "%s / %s" % [_get_category(a_meta), a_meta.get("title", a_template_name)]
		var b_label := "%s / %s" % [_get_category(b_meta), b_meta.get("title", b_template_name)]
		return a_label < b_label
	)

	for match_data in matches:
		var template_name : String = match_data.template_name
		var node_meta : Dictionary = current_node_types[template_name]
		var category := _get_category(node_meta)
		var node_button := Button.new()
		node_button.text = "%s / %s" % [category, node_meta.get("title", str(template_name))]
		node_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(node_button, category)
		node_button.pressed.connect(_select_node.bind(template_name))
		if node_meta.has("tooltip"):
			node_button.tooltip_text = node_meta.tooltip
		search_results.add_child(node_button)

	for input_idx in range(current_inputs.size()):
		var input = current_inputs[input_idx]
		var label : String = FlowNodeBase.editorDisplayName(input.name)
		var haystack := "%s %s" % [input.name, label]
		if not haystack.to_lower().contains(query.to_lower()):
			continue
		var input_button := Button.new()
		input_button.text = "%s / %s" % [INPUTS_CATEGORY, label]
		input_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		input_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(input_button, INPUTS_CATEGORY)
		input_button.pressed.connect(_select_input.bind(input_idx))
		search_results.add_child(input_button)

	for action in current_actions:
		var label := str(action.get("label", "Action"))
		if not label.to_lower().contains(query.to_lower()):
			continue
		var action_button := Button.new()
		action_button.text = "%s / %s" % [ACTIONS_CATEGORY, label]
		action_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(action_button, ACTIONS_CATEGORY)
		action_button.pressed.connect(_select_action.bind(action.id))
		search_results.add_child(action_button)

	for definition: FlowGraphRedirect in current_redirectors:
		if not definition or not definition.name.to_lower().contains(query.to_lower()):
			continue
		var redirect_button := Button.new()
		redirect_button.text = "%s / %s" % [
			REDIRECTORS_CATEGORY,
			definition.name,
		]
		redirect_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		redirect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_category_button_style(redirect_button, REDIRECTORS_CATEGORY)
		redirect_button.pressed.connect(
			_select_redirect.bind(definition.ensureId())
		)
		search_results.add_child(redirect_button)

func _apply_category_button_style(button : Button, category_name : String):
	var base_color := _get_display_category_color(category_name)
	var normal_color := Color(base_color.r, base_color.g, base_color.b, 1.0)
	var hover_color := normal_color.darkened(0.18)
	var pressed_color := normal_color
	button.add_theme_stylebox_override("normal", _make_button_style(normal_color))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_color, Color.WHITE, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_color, Color.WHITE, 1))
	button.add_theme_stylebox_override("hover_pressed", _make_button_style(hover_color, Color.WHITE, 1))
	button.add_theme_color_override("font_color", _get_text_color_for_bg(normal_color))
	button.add_theme_color_override("font_hover_color", _get_text_color_for_bg(hover_color))
	button.add_theme_color_override("font_pressed_color", _get_text_color_for_bg(pressed_color))

func _make_button_style(color : Color, border_color : Color = Color.TRANSPARENT, border_width : int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _get_display_category_color(category_name : String) -> Color:
	if category_name == RECENTS_CATEGORY:
		return Color(0.55, 0.55, 0.55)
	if category_name == INPUTS_CATEGORY:
		return Color(0.32, 0.52, 0.85)
	if category_name == ACTIONS_CATEGORY:
		return Color(0.45, 0.45, 0.48)
	if category_name == REDIRECTORS_CATEGORY:
		return Color(0.55, 0.36, 0.68)
	return FlowNodeStyle.getCategoryColor(category_name)

func _get_text_color_for_bg(bg_color : Color) -> Color:
	var luminance := bg_color.r * 0.299 + bg_color.g * 0.587 + bg_color.b * 0.114
	if luminance > 0.55 and bg_color.a > 0.5:
		return Color(0.08, 0.08, 0.08)
	return Color(0.95, 0.95, 0.95)

func _clear_results():
	for child in search_results.get_children():
		search_results.remove_child(child)
		child.queue_free()

func _matches_search(template_name : String, query : String) -> bool:
	return _get_search_score(template_name, query) > 0

func _get_search_score(template_name : String, query : String) -> int:
	var node_meta : Dictionary = current_node_types[template_name]
	var normalized_query := query.strip_edges().to_lower()
	if normalized_query.is_empty():
		return 0

	var title := str(node_meta.get("title", template_name)).to_lower()
	if title == normalized_query:
		return 12
	if title.begins_with(normalized_query):
		return 10

	var keywords = node_meta.get("keywords", [])
	if keywords is Array or keywords is PackedStringArray:
		for keyword in keywords:
			if str(keyword).to_lower().begins_with(normalized_query):
				return 10
	elif str(keywords).to_lower().begins_with(normalized_query):
		return 10

	if title.contains(normalized_query):
		return 8

	var secondary_haystack := "%s %s %s %s" % [
		template_name,
		_get_category(node_meta),
		str(keywords),
		str(node_meta.get("tooltip", "")),
	]
	if secondary_haystack.to_lower().contains(normalized_query):
		return 5
	return 0

func _get_category(node_meta : Dictionary) -> String:
	var category : String = node_meta.get("category", "Others...")
	if category == "":
		return "Others..."
	return category

func _fit_height_to_categories(category_count : int):
	var desired_height := POPUP_VERTICAL_PADDING + category_count * CATEGORY_ROW_HEIGHT
	size = Vector2i(MIN_POPUP_SIZE.x, max(MIN_POPUP_SIZE.y, desired_height))

func _is_compatible(node_meta : Dictionary, required_input_type : FlowData.DataType, required_output_type : FlowData.DataType) -> bool:
	
	# Invalid and Any are kind of similar here.
	if required_input_type == FlowData.DataType.Invalid and required_output_type == FlowData.DataType.Invalid:
		return true
	if required_input_type == FlowData.DataType.Any and (required_output_type == FlowData.DataType.Invalid or required_output_type == FlowData.DataType.Any):
		return true		

	var ports = node_meta.ins if required_input_type != FlowData.DataType.Invalid else node_meta.outs
	var required_type = required_input_type if required_input_type != FlowData.DataType.Invalid else required_output_type
	for port in ports:
		if port.get("data_type", FlowData.DataType.Invalid) == required_type:
			return true
	return false

func _select_node(template_name : String):
	recently_used.erase(template_name)
	recently_used.push_front(template_name)
	if recently_used.size() > MAX_RECENT:
		recently_used.resize(MAX_RECENT)
	node_selected.emit(template_name)
	hide()
	on_closed.emit()

func _select_input(input_idx : int):
	input_selected.emit(input_idx)
	hide()
	on_closed.emit()

func _select_action(action_id : int):
	action_selected.emit(action_id)
	hide()
	on_closed.emit()

func _select_redirect(redirect_id: StringName) -> void:
	redirect_selected.emit(redirect_id)
	hide()
	on_closed.emit()
