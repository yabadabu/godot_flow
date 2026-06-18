@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Comments",
		"settings" : CommentNodeSettings,
		"category" : "Debug",
		"ins" : [], 
		"outs" : [],
		"tooltip" : "Adds a custom text to the graph",
	}

var label : Label
var panel_sb: StyleBoxFlat
var panel_selected_sb: StyleBoxFlat

func _ready():
	label = null
	settings.hue = randf()
	super._ready()

func refreshFromSettings():
	settings.disabled = false
	settings.inspect_enabled = false
	settings.debug_enabled = false
	super.refreshFromSettings()
	settings.hue = int(settings.hue * 20) * 0.05
	if not label:
		label = Label.new()
		label.label_settings = LabelSettings.new()
		label.label_settings.font_size = 16
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		add_child( label )
		panel_sb = get_theme_stylebox("panel", "GraphNode").duplicate(true)
		panel_sb.border_width_bottom = 0
		panel_sb.border_width_left = 0
		panel_sb.border_width_right = 0
		panel_selected_sb = get_theme_stylebox("panel_selected", "GraphNode").duplicate(true)
		panel_selected_sb.border_width_bottom = 2
		panel_selected_sb.border_width_left = 2
		panel_selected_sb.border_width_right = 2
		panel_selected_sb.border_color = Color.WHITE
		add_theme_stylebox_override("panel", panel_sb)
		add_theme_stylebox_override("panel_selected", panel_selected_sb)
	
	if panel_sb:
		panel_sb.bg_color = Color.from_hsv( settings.hue, 0.5, 0.4 )
		panel_selected_sb.bg_color = Color.from_hsv( settings.hue, 0.5, 0.4 )
		if label:
			label.text = settings.text

	resizable = true
