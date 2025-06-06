extends Control

@onready var gedit : GraphEdit = %GraphEdit
@onready var info : Label = %LabelInfo
@onready var node_info : Label = %LabelNodeInfo
@onready var data_inspector = %DataInspector

var comment_padding = Vector2( 40, 40 )

var packed_node = preload("res://flow_node_base.tscn")

var local_drop_position : Vector2 = Vector2(0,0)
var auto_connect_from_node : String
var auto_connect_from_port : int
var auto_connect_to_node : String
var auto_connect_to_port : int

var counter : int = 0
var min_id = 1000
var max_id = min_id

# During graph deps evaluation
var nodes_by_name = {}

var node_types = { 
	"grid" : "Grid",
	"spawn_meshes" : "Spawn Meshes",
	"transform" : "Transform",
	"select" : "Select",
}

func getNewName():
	counter+= 1
	return "id_%04d" % counter

func _ready():
	#gedit.theme.ac = Color( 1, 0.5, 0.5 );
	var pm = %PopupMenu as PopupMenu
	for key in node_types.keys():
		var label = node_types[ key ]
		pm.add_item(label, max_id, KEY_NONE )
		max_id += 1
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


# Get all connections for a specific node
func getNodeInputConnections(node_name: StringName) -> Array[Dictionary]:
	var conns : Array[Dictionary] = []	    # Connections coming INTO this node
	var all_connections = gedit.get_connection_list()
	for connection in all_connections:
		if connection.to_node == node_name:
			conns.append( connection )
	return conns


# Get all connections for a specific node
func getNodeConnections(node_name: StringName) -> Dictionary:
	var node_connections = {
		"inputs": [],    # Connections coming INTO this node
		"outputs": []    # Connections going OUT of this node
	}
	
	# Get all connections in the graph
	var all_connections = gedit.get_connection_list()
	
	# Filter connections for this specific node
	for connection in all_connections:
		# connection is a Dictionary with: from_node, from_port, to_node, to_port
		
		if connection.to_node == node_name:
			# This node is receiving input
			node_connections.inputs.append({
				"from_node": connection.from_node,
				"from_port": connection.from_port,
				"to_port": connection.to_port
			})
		
		if connection.from_node == node_name:
			# This node is sending output
			node_connections.outputs.append({
				"to_node": connection.to_node,
				"to_port": connection.to_port,
				"from_port": connection.from_port
			})
	
	return node_connections

func localToGraphCoords( local_coords : Vector2 ):
	#var view_zero_in_scroll_offset = gedit.scroll_offset / gedit.zoom
	return ( gedit.scroll_offset + local_coords ) / gedit.zoom

func addNode( node_name ):
	
	var node = packed_node.instantiate() as GraphNode
	var logic_uri = "res://flow_nodes/%s.gd" % node_name

	# Check if file exists first
	if not ResourceLoader.exists(logic_uri):
		push_error("Error: Logic file does not exist at ", logic_uri)
		return null	
	
	var logic = load( logic_uri ) as Script
	if not logic:
		push_error("Error: Scene file failed to load ", logic_uri)
		return null	
		
	node.set_script(logic)
		
	node.name = getNewName() + ( "_%s" % node_name )
	node.position_offset = localToGraphCoords(local_drop_position)
	node.title = node.getTitle()
	node.initFromScript()
	#node.size.x = 400
	gedit.add_child(node)
	
	if auto_connect_from_node:
		gedit.connect_node(auto_connect_from_node, auto_connect_from_port, node.name, 0)
		auto_connect_from_node = ""
		
	if auto_connect_to_node:
		gedit.connect_node(node.name, 0, auto_connect_to_node, auto_connect_to_port )
		auto_connect_to_node = ""
	
	for prev_node in getSelectedNodes():
		prev_node.selected = false
	node.selected = true
	node.visible = true

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
		elif key == KEY_A:
			openAddMenu()
		elif key == KEY_C:
			addComment()
		elif key == KEY_D:
			toggleDebug()
		elif key == KEY_E:
			toggleInspection()
		elif key == KEY_R:
			evalGraph()

func toggleDebug():
	var nodes = getSelectedNodes()
	for n in nodes:
		n.debug_enabled = !n.debug_enabled

func toggleInspection():
	var nodes = getSelectedNodes()
	if nodes.size() != 1:
		data_inspector.setNode( null )
		return
	data_inspector.setNode( nodes[0] )

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
			new_text = "%s PosOff:%s N:%s T:%s" % [node.name, node.position_offset, node.name, node.title ]
			var conns = getNodeConnections( node.name )
			new_text += " InConns:%d OutConn:%d" % [conns.inputs.size(), conns.outputs.size() ]
			break
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

func _on_popup_menu_id_pressed(id: int) -> void:
	if id >= min_id && id < max_id:
		var idx = id - min_id
		var key = node_types.keys()[ idx ]
		addNode( key )
	else:
		# Highlight the connection...
		var nodes = getSelectedNodes()
		if nodes.size() > 1:
			var node = nodes[0]
			var target = nodes[1]
			gedit.set_connection_activity( node.name, 0, target.name, 0, 1.0)

func _on_graph_edit_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	gedit.connect_node(from_node, from_port, to_node, to_port)
	
func _on_graph_edit_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	gedit.disconnect_node(from_node, from_port, to_node, to_port)

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

func getDeps( node : FlowNodeBase ) -> Array[ FlowNodeBase ]:
	node.deps = getNodeInputConnections( node.name )
	var deps : Array[ FlowNodeBase ] = [ node ]
	for dep in node.deps:
		var dep_node = nodes_by_name.get( dep.from_node, null )
		if not dep_node:
			push_error( "Failed to find node %s in the graph" % dep.from_node )
			continue
		var req_deps = getDeps( dep_node )
		deps.append_array( req_deps )
	return deps
	
func getEvalOrder():
	# Find targets, like spawn meshes
	var finals : Array[ FlowNodeBase ]
	for child in gedit.get_children():
		var node = child as FlowNodeBase
		if not node:
			continue
		if not node.isFinal():
			continue
		finals.append( node )
	
	# for each node, find requirements
	# A -
	#    -- C - D
	# B -
	# D -> C -> A -> B
	var all_deps : Array[ FlowNodeBase ]
	for node in finals:
		var node_deps = getDeps( node )
		all_deps.append_array( node_deps )
	
	# Evaluate in inverse order
	# B, A, C, D
	all_deps.reverse()	
	return all_deps

func evalGraph():
	print( "evalGraph starts" )
	nodes_by_name = {}
	for c in gedit.get_children():
		print( "  ", c.name )
		nodes_by_name[ c.name ] = c
	
	print( "getEvalOrder..." )
	var nodes_to_eval = getEvalOrder( )
	for node in nodes_to_eval:
		print( "  ", node )
		
		for req in node.deps:
			print("  - req : ", req )
			var req_node = nodes_by_name.get( req.from_node )
			var data = req_node.get_output( req.from_port )
			node.set_input( req.to_port, data )
			#node.set_input( req.)
		node.preExecute()
		node.execute()
