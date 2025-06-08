@tool
extends Control
class_name FlowGraphEditor

var current_resource: FlowGraphResource

@onready var gedit : GraphEdit = %GraphEdit
@onready var data_inspector : Control

# The inspector shows the settings property of the node
var inspector: EditorInspector
var inspected_node : Node

var packed_node = preload("res://addons/flow_nodes_editor/node.tscn")

# New nodes generation
var local_drop_position : Vector2 = Vector2(0,0)
var auto_connect_from_node : String
var auto_connect_from_port : int
var auto_connect_to_node : String
var auto_connect_to_port : int
var counter : int = 0

# Ranges for the menu
var min_id = 1000
var max_id = min_id

var comment_padding = Vector2( 40, 40 )

# During graph deps evaluation
var gedit_nodes_by_name = {}

var node_types = { }

func setResourceToEdit( new_resource : FlowGraphResource ):
	print( "setResourceToEdit %s" % new_resource )
	if current_resource == new_resource:
		return
	if current_resource:
		saveResource()
	current_resource = new_resource
	# Remove exiting nodes
	for child in gedit.get_children():
		if child is GraphNode:
			child.queue_free()
			
	if current_resource != null:
		print( "Recoverting %d nodes" % current_resource.nodes.size() )
		for res_node in current_resource.nodes:
			print( "Recovering node %s" % [ res_node ])
			var node = addNodeFromTemplate( res_node.template, res_node.settings )
			if not node:
				push_error( "Failed to recover node %s %s" % [ res_node ])
				continue
			node.position_offset = res_node.position_offset
			node.name = res_node.name
		
		print( "Recovering %d conns" % current_resource.conns.size() )
		for conn in current_resource.conns:
			print( "Regenerating conn %s" % [conn])
			var err = gedit.connect_node( conn.from_node, conn.from_port, conn.to_node, conn.to_port )	
			if err:
				push_error("Error adding conn %s" % [err])

func saveResource():
	if current_resource == null:
		return
	current_resource.nodes.clear()
	current_resource.conns.clear()
	for child in gedit.get_children():
		var node = child as FlowNodeBase
		if not node:
			continue
		var stored_data = {
			"position_offset" : node.position_offset,
			"name" : node.name,
			"template" : node.node_template,
			"settings" : node.settings,
			}
		print( "Saving node %s" % [stored_data])
		current_resource.nodes.append(stored_data)

	for connection in gedit.get_connection_list():
		current_resource.conns.append( connection.duplicate() )

func getNewName( suffix : String ):
	counter+= 1
	return "id_%04d_%s" % [ counter, suffix ]

func scanAvailableNodes():
	var directory_path := "res://addons/flow_nodes_editor/nodes"
	var files := ResourceLoader.list_directory(directory_path) 
	for file in files:
		var stem = file.get_basename()
		if stem.ends_with("_settings"):
			continue
		var full_res_path = directory_path + "/" + file
		var loaded_class : Script = load( full_res_path ) as Script
		if not loaded_class:
			push_error("Failed to load class %s" % full_res_path )
			continue
		var instance = loaded_class.new() as FlowNodeBase
		var meta = instance.getMeta()
		meta.factory = loaded_class
		#print( "Meta is %s " % str(meta) )
		node_types[ stem ] = meta

func populatePopupMenu():
	
	min_id = 1000
	max_id = min_id
	
	#gedit.theme.ac = Color( 1, 0.5, 0.5 );
	var pm = %PopupMenu as PopupMenu
	pm.clear();
	pm.add_item( "Clear", 0, KEY_NONE )
	pm.add_separator( "", -1 )
	
	for key in node_types.keys():
		var label = node_types[ key ].title
		print( "Adding menu", label)
		pm.add_item(label, max_id, KEY_NONE )
		max_id += 1

func _ready():
	
	scanAvailableNodes()
	populatePopupMenu()
		
	inspector = EditorInspector.new()
	inspector.custom_minimum_size = Vector2( 200, 600 )
	var splitter = $VBoxContainer/VSplitContainer
	splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.add_child( inspector )
	splitter.split_offset = 400
	
	gedit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gedit.size_flags_vertical = Control.SIZE_EXPAND_FILL	
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.custom_minimum_size.y = 150
	inspector.property_edited.connect( onNodePropertyChanged )
	
func onNodePropertyChanged( prop_name : String):
	if inspected_node:
		print( "Node %s.%s has changed" % [ inspected_node.name, prop_name ])
		inspected_node.refreshFromSettings()
		evalGraph()
		
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
	inspected_node = null
	inspector.edit(null)
	
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

# Get all connections aarriving to a specific node
func getNodeInputConnections(node_name: StringName) -> Array[Dictionary]:
	var conns : Array[Dictionary] = []	    # Connections coming INTO this node
	var all_connections = gedit.get_connection_list()
	for connection in all_connections:
		if connection.to_node == node_name:
			conns.append( connection )
	return conns

func localToGraphCoords( local_coords : Vector2 ):
	#var view_zero_in_scroll_offset = gedit.scroll_offset / gedit.zoom
	return ( gedit.scroll_offset + local_coords ) / gedit.zoom

func addNodeFromTemplate( node_template, settings = null ):
	print( "addNode %s" % node_template)
	var node = packed_node.instantiate() as GraphNode
	var meta = node_types.get( node_template, null )
	if not meta:
		push_error("node_type %s is not registered", node_template)
		return null	
	print( "Meta:", str(meta) )
		
	node.set_script(meta.factory)

	node.node_template = node_template
	node.name = getNewName(node_template)
	node.position_offset = localToGraphCoords(local_drop_position)
	if settings:
		node.settings = settings
	else:
		if meta.has( "settings" ):
			print( "Assigning settings of type %s" % meta.settings )
			print( "node is %s" % node )
			node.settings = meta.settings.new()
		else:
			print( "Assigning default settings" )
			node.settings = NodeSettings.new()
	node.settings.title = meta.title
	node.initFromScript()
	node.title = node.getTitle()
	node.size = Vector2(32,32)
	node.tooltip_text = meta.get( "tooltip", "" )
	gedit.add_child(node)
	return node
	
func addNode( node_template ):
	var node = addNodeFromTemplate( node_template )
	if not node:
		return null
		
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
	saveResource()

# ------------------------------------------------
func _on_graph_edit_gui_input(event):
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
			evalGraph()
		elif key == KEY_R:
			evalGraph()

func toggleDebug():
	var nodes = getSelectedNodes()
	for node in nodes:
		node.settings.debug_enabled = !node.settings.debug_enabled
		node.refreshFromSettings()

func toggleInspection():
	if not data_inspector:
		return
	var nodes = getSelectedNodes()
	if nodes.size() != 1:
		data_inspector.setNode( null )
		return
	var node = nodes[0]
	data_inspector.setNode( node )
	node.refreshFromSettings()

func addComment():
	var nodes = getSelectedNodes()
	var rect = getRectOfNodes( nodes )
	rect.position -= comment_padding
	rect.size += comment_padding * 2
	
	var frame := GraphFrame.new()
	frame.name = getNewName("comment")
	frame.title = "My Comments..."
	frame.position_offset = rect.position
	frame.size = rect.size
	frame.tint_color = Color.DARK_SLATE_BLUE
	frame.tint_color_enabled = true
	gedit.add_child(frame)
	
	for node in nodes:
		gedit.attach_graph_element_to_frame( node.name, frame.name )
	
func _on_graph_edit_node_selected(node):
	
	#var current_main_screen = EditorInterface.get_editor_main_screen()
	#print( current_main_screen )
	if not inspector:
		push_error("inspector is null")
		return
	inspector.edit( node.settings )
	inspected_node = node
	#EditorInterface.inspect_object(node)
	#EditorInterface.set_main_screen_editor("3D")

func _on_graph_edit_popup_request(at_position):
	local_drop_position = at_position
	var p : PopupMenu = %PopupMenu
	
	p.size = Vector2( 400,200 )
	#p.popup_centered( Vector2( 400, 200 ))
	p.position = get_screen_position() + at_position
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
	saveResource()
	
func _on_graph_edit_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	gedit.disconnect_node(from_node, from_port, to_node, to_port)
	saveResource()

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
		var dep_node = gedit_nodes_by_name.get( dep.from_node, null )
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
		if node.settings.inspect_enabled:
			finals.clear()
			finals.append( node )
			break
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
	#print( "evalGraph starts" )
	gedit_nodes_by_name = {}
	for c in gedit.get_children():
		gedit_nodes_by_name[ c.name ] = c
	
	#print( "getEvalOrder..." )
	var nodes_to_eval = getEvalOrder( )
	for node in nodes_to_eval:
		print( "  ", node )
		
		for req in node.deps:
			var req_node = gedit_nodes_by_name.get( req.from_node )
			var data = req_node.get_output( req.from_port )
			node.set_input( req.to_port, data )
			
		node.preExecute()
		node.execute()
		
		if node.settings.inspect_enabled:
			data_inspector.refresh()

func _on_button_reload_pressed() -> void:
	scanAvailableNodes()
	populatePopupMenu()

func _on_button_save_pressed() -> void:
	if current_resource:
		ResourceSaver.save(current_resource)
