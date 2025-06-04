extends Control

@onready var gedit : GraphEdit = %GraphEdit
@onready var info : Label = %LabelInfo
@onready var node_info : Label = %LabelNodeInfo

var local_drop_position : Vector2 = Vector2(0,0)

# ------------------------------------------------
func getSelectedNodes():
	var nodes = []
	for child in gedit.get_children():
		var node = child as GraphNode
		if node and node.selected:
			nodes.push_back(node)
	return nodes

func deleteNodes( nodes ):
	for child in nodes:
		var node = child as GraphNode
		node.queue_free()

func deleteSelectedNodes():
	var nodes = getSelectedNodes()
	deleteNodes( nodes )
	
func localToGraphCoords( local_coords : Vector2 ):
	#var view_zero_in_scroll_offset = gedit.scroll_offset / gedit.zoom
	return ( gedit.scroll_offset + local_coords ) / gedit.zoom

func addNode( node_name ):
	var uri = "res://flow_nodes/%s.tscn" % node_name

	# Check if file exists first
	if not ResourceLoader.exists(uri):
		push_error("Error: Scene file does not exist at ", uri)
		return null	
	
	var scene = load( uri ) as PackedScene
	if not scene:
		push_error("Error: Scene file failed to load ", uri)
		return null	
		
	var node = scene.instantiate() as GraphNode
	if not node:
		push_error("Error: Scene file should contain a GraphNode ", uri)
		return null
		
	node.position_offset = localToGraphCoords(local_drop_position)
	node.size.x = 400
	gedit.add_child(node)

# ------------------------------------------------
func _on_graph_edit_gui_input(event):
	updateNodeInfo()

	var evt_mouse_motion = event as InputEventMouseMotion
	if evt_mouse_motion:
		var local_pos = evt_mouse_motion.position
		var mouse_in_scroll_offset = localToGraphCoords( local_pos )
		info.text = "Local:%s Z:%s SO:%s G:%s" % [ local_pos, gedit.zoom, gedit.scroll_offset, mouse_in_scroll_offset ]
		return
		
	var evt_key = event as InputEventKey
	if evt_key:
		var key = evt_key.keycode
		if key == KEY_X:
			deleteSelectedNodes()
		if key == KEY_A:
			openAddMenu()

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
	local_drop_position = at_position
	var p : PopupMenu = %PopupMenu
	p.size = Vector2( 400,200 )
	p.popup_centered( Vector2( 400, 200 ))
	p.position = get_screen_position() + at_position
	p.show()
	p.popup()
	
func openAddMenu():
	var pos = get_local_mouse_position()
	_on_graph_edit_popup_request( pos )

func _on_button_add_grid_pressed():
	addNode( "grid" )

func _on_popup_menu_id_pressed(id: int) -> void:
	addNode( "grid" )
