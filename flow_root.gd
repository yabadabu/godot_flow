extends Control

@onready var gedit : GraphEdit = %GraphEdit
@onready var info : Label = %LabelInfo
@onready var node_info : Label = %LabelNodeInfo

var comment_padding = Vector2( 40, 40 )

var local_drop_position : Vector2 = Vector2(0,0)
var auto_connect_from_node : String
var auto_connect_from_port : int
var auto_connect_to_node : String
var auto_connect_to_port : int

var counter : int = 0

func getNewName():
	counter+= 1
	return "id_%04d" % counter

func _ready():
	#gedit.theme.ac = Color( 1, 0.5, 0.5 );
	pass
	
# ------------------------------------------------
func getSelectedNodes() -> Array[GraphNode]:
	var nodes : Array[GraphNode] = []
	for child in gedit.get_children():
		var node = child as GraphNode
		if node and node.selected:
			nodes.push_back(node)
	return nodes

func deleteNodes( nodes : Array[GraphNode] ):
	for node in nodes:
		node.queue_free()

func deleteSelectedNodes():
	var nodes := getSelectedNodes()
	deleteNodes( nodes )
	
func getRectOfNodes( nodes : Array[GraphNode] ):
	var r : Rect2
	var first : bool = true
	for node in nodes:
		var p0 = node.position_offset
		var p1 = p0 + node.size
		if first:
			r.position = p0
			r.size = Vector2(0,0)
			first = false
		else:
			r = r.expand( p0 )
		r = r.expand( p1 )
	return r

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
		
	node.name = getNewName()
	node.position_offset = localToGraphCoords(local_drop_position)
	node.size.x = 400
	gedit.add_child(node)
	
	if auto_connect_from_node:
		gedit.connect_node(auto_connect_from_node, auto_connect_from_port, node.name, 0)
		auto_connect_from_node = ""
		
	if auto_connect_to_node:
		gedit.connect_node(node.name, 0, auto_connect_to_node, auto_connect_to_port )
		auto_connect_to_node = ""

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
	if evt_key and evt_key.pressed:
		var key = evt_key.keycode
		if key == KEY_X:
			deleteSelectedNodes()
		if key == KEY_A:
			openAddMenu()
		if key == KEY_C:
			addComment()

func addComment():
	var nodes = getSelectedNodes()
	var rect = getRectOfNodes( nodes )
	rect.position -= comment_padding
	rect.size += comment_padding * 2
	
	var frame := GraphFrame.new()
	frame.name = getNewName()
	frame.title = "My Comments..."
	frame.position_offset = rect.position
	frame.size = rect.size
	frame.tint_color = Color.DARK_SLATE_BLUE
	frame.tint_color_enabled = true
	gedit.add_child(frame)
	
	for node in nodes:
		gedit.attach_graph_element_to_frame( node.name, frame.name )

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
	if id == 0:
		addNode( "grid" )
	else:
		# Highlight the connection...
		var nodes = getSelectedNodes()
		if nodes.size() > 1:
			var node = nodes[0]
			var target = nodes[1]
			gedit.set_connection_activity( node.name, 0, target.name, 0, 1.0)

func _on_graph_edit_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# This is called when the user tries to connect two ports
	# You can add validation logic here if needed
	# Create the connection
	gedit.connect_node(from_node, from_port, to_node, to_port)
	# Optional: Store connection data for your own logic
	print("Connected: ", from_node, ":", from_port, " -> ", to_node, ":", to_port)
	
func _on_graph_edit_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Remove the connection
	gedit.disconnect_node(from_node, from_port, to_node, to_port)
	
	# Optional: Update your own data structures
	print("Disconnected: ", from_node, ":", from_port, " -> ", to_node, ":", to_port)

func _on_graph_edit_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	auto_connect_from_node = from_node
	auto_connect_from_port = from_port
	local_drop_position = release_position
	_on_graph_edit_popup_request( local_drop_position )

func _on_graph_edit_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	auto_connect_to_node = to_node
	auto_connect_to_port = to_port
	local_drop_position = release_position
	_on_graph_edit_popup_request( local_drop_position )
