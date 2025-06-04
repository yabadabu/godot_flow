extends Control

@onready var gedit : GraphEdit = %GraphEdit
@onready var info : Label = %LabelInfo
@onready var node_info : Label = %LabelNodeInfo

func _on_graph_edit_gui_input(event):
	var evt_mouse_motion = event as InputEventMouseMotion
	if evt_mouse_motion:
		info.text = "Local:%s Z:%s SO:%s" % [ event.position, gedit.zoom, gedit.scroll_offset ]
		updateNodeInfo()

func updateNodeInfo():
	var new_text : String
	for c in gedit.get_children():
		var node = c as GraphNode
		if node and node.selected:
			new_text = "PosOff:%s N:%s T:%s" % [node.position_offset, node.name, node.title ]
	node_info.text = new_text
	
func _on_graph_edit_node_selected(_node):
	updateNodeInfo()

func _on_graph_edit_popup_request(at_position):
	var p = %PopupMenu
	p.position = get_screen_position() + at_position
	p.popup()
	p.show()
	
func add_node( node ):
	pass

func _on_button_add_grid_pressed():
	pass # Replace with function body.
