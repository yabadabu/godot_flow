@tool
extends FlowGraphNodeUI
class_name FlowGraphNodeUIComment

@onready var label: RichTextLabel = %RichTextLabel
var panel_sb: StyleBoxFlat
var panel_selected_sb: StyleBoxFlat

const DEFAULT_COMMENT_SIZE := Vector2(220, 120)

func shouldAutoSize() -> bool:
	return false

func initFromScript():
	super.initFromScript()
	refreshComment()

func updateStyle() -> void:
	super.updateStyle()
	panel_sb = get_theme_stylebox("panel", "GraphNode").duplicate(true) as StyleBoxFlat
	panel_selected_sb = get_theme_stylebox("panel_selected", "GraphNode").duplicate(true) as StyleBoxFlat
	panel_selected_sb.border_width_bottom = 2
	panel_selected_sb.border_width_left = 2
	panel_selected_sb.border_width_right = 2
	panel_selected_sb.border_color = Color.WHITE
	refreshCommentStyle()
	add_theme_stylebox_override("panel", panel_sb)
	add_theme_stylebox_override("panel_selected", panel_selected_sb)

func refreshCommentStyle() -> void:
	if not flow_node:
		return
	var background_color := Color.from_hsv(flow_node.hue, 0.5, 0.4)
	if panel_sb:
		panel_sb.bg_color = background_color
	if panel_selected_sb:
		panel_selected_sb.bg_color = background_color

func initializeView():
	super.initializeView()
	resizable = true
	if flow_node.ui_size.x > 0.0 and flow_node.ui_size.y > 0.0:
		size = flow_node.ui_size
	else:
		size = DEFAULT_COMMENT_SIZE
		flow_node.ui_size = size
	resize_request.connect(_on_resize_requested)

func _on_resize_requested(new_size: Vector2) -> void:
	size = new_size
	flow_node.ui_size = new_size
	if editor:
		editor.queueSave()

func refreshComment() -> void:
	var comment := flow_node
	label.text = comment.text
	
func regenerateFromFlowNode(prop_name: StringName = StringName()):
	super.regenerateFromFlowNode(prop_name)
	if is_instance_valid(label):
		label.text = flow_node.text
	refreshCommentStyle()
	
