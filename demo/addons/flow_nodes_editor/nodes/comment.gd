@tool
extends FlowNodeBase

@export_group("Comment")
@export_multiline var text := "..."
@export_range(0.0, 1.0)  var hue : float = 0.5

var is_ready : bool = false
var label : Label
var panel_sb: StyleBoxFlat
var panel_selected_sb: StyleBoxFlat

func _init():
	meta_node = {
		"title" : "Comments",
		"category" : "Debug",
		"ins" : [], 
		"outs" : [],
		"tooltip" : "Adds a custom text to the graph",
	}
	hue = randf()
	
#func refreshFromSettings():
	#disabled = false
	#inspect_enabled = false
	#debug_enabled = false
	#super.refreshFromSettings()
	#hue = int(hue * 20) * 0.05
	## Otherwise I have problems with the copy/paste of nodes
	## and the direct creation of new nodes
	#if not is_inside_tree():
		#call_deferred("refreshFromSettings")
		#return
	#if label:
		#label.text = text
	
func initFromScript():
	if not label:
		label = Label.new()
		label.name = "TitleLabel"
		label.add_theme_color_override("font_color", Color.RED)
		label.custom_minimum_size = Vector2(100, 30)
		label.custom_minimum_size = Vector2(50, 20)
		label.label_settings = LabelSettings.new()
		label.label_settings.font_size = 16
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		#add_child( label )
		
	if not panel_sb:
		#panel_sb = get_theme_stylebox("panel", "GraphNode").duplicate(true)
		panel_sb.border_width_bottom = 0
		panel_sb.border_width_left = 0
		panel_sb.border_width_right = 0
		#panel_selected_sb = get_theme_stylebox("panel_selected", "GraphNode").duplicate(true)
		panel_selected_sb.border_width_bottom = 2
		panel_selected_sb.border_width_left = 2
		panel_selected_sb.border_width_right = 2
		panel_selected_sb.border_color = Color.WHITE
		#add_theme_stylebox_override("panel", panel_sb)
		#add_theme_stylebox_override("panel_selected", panel_selected_sb)
	
	if panel_sb:
		panel_sb.bg_color = Color.from_hsv( hue, 0.5, 0.4 )
		panel_selected_sb.bg_color = Color.from_hsv( hue, 0.5, 0.4 )
	
	label.text = text
	#resizable = true
