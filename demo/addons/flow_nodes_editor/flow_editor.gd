@tool
extends Control
class_name FlowGraphEditor

var current_resource: FlowGraphResource
var resource_owner : Node3D
var ctx := FlowData.EvaluationContext.new()
var regen_pending := false
var auto_regen := true

# Regen needs to take place once the graph nodes have been added/removed
# from the actual scene, but there are more nodes child of the graph-edit
var num_non_nodes_children = 0

@onready var gedit : GraphEdit = %GraphEdit
@onready var data_inspector : Control
@onready var info : Label = %LabelInfo

# The inspector shows the settings property of the current node
var inspector: EditorInspector
var inspected_node : Node
var make_inspector_visible : Callable

# This is the default graph-node instantiated, the script contains the logic
var packed_node = preload("res://addons/flow_nodes_editor/node.tscn")
const directory_path := "res://addons/flow_nodes_editor/nodes"

# New nodes generation using the editor
var local_drop_position : Vector2 = Vector2(0,0)
var auto_connect_from_node : String
var auto_connect_from_port : int
var auto_connect_to_node : String
var auto_connect_to_port : int
var new_name_counter : int = 0

# Ranges for the menu
var min_id = 1000
var max_id = min_id
var menu_ids : Dictionary = {}

var comment_padding = Vector2( 40, 40 )

# Required during evaluation
var gedit_nodes_by_name = {}

var ui_scale = 1.0
var node_types = { }

var popup_menu = null

func setResourceToEdit( new_resource : FlowGraphResource, new_resource_owner : Node3D ):
	print( "setResourceToEdit %s" % new_resource )
	
	# Time to save the current resource
	if current_resource == new_resource and resource_owner == new_resource_owner:
		return
	if current_resource:
		saveResource()
	current_resource = new_resource
	resource_owner = new_resource_owner
	
	# Remove exiting nodes
	var children = []
	for child in gedit.get_children():
		if child is GraphNode:
			child.queue_free()
			children.append( child )
			
	gedit.clear_connections()
	for child in children:
		gedit.remove_child( child )
	num_non_nodes_children = gedit.get_child_count()
	
	gedit_nodes_by_name.clear()
	inspector.edit( null )
	inspected_node = null
	var node_in_data_inspector = null
	
	if current_resource != null:
		
		# Register the input_* nodes before trying to load the nodes
		for input in current_resource.inputs.inputs:
			print( "Regiistering get_graph_input %s" % input.name )
			var node_type_name := "input_%s" % input.name
			registerNodeType( node_type_name, "input.gd")
			print( "done" )
		
		print( "Recovering %d nodes" % current_resource.nodes.size() )
		for res_node in current_resource.nodes:
			#print( "Recovering node %s" % [ res_node ])
			var node = addNodeFromTemplate( res_node.template, res_node.name, res_node.settings )
			if not node:
				push_error( "Failed to recover node %s" % [ res_node ])
				continue
			node.position_offset = res_node.position_offset * ui_scale
			if node.settings.inspect_enabled:
				node_in_data_inspector = node
		
		print( "Recovering %d conns" % current_resource.conns.size() )
		for conn in current_resource.conns:
			#print( "Regenerating conn %s" % [conn])
			var err = gedit.connect_node( conn.from_node, conn.from_port, conn.to_node, conn.to_port )	
			if err:
				push_error("Error adding conn %s from %s" % [err, conn])
				
		gedit.zoom = current_resource.view_zoom
		gedit.scroll_offset = current_resource.view_offset
		new_name_counter = current_resource.new_name_counter

	data_inspector.setNode( node_in_data_inspector )

	queueRegen()
	ctx.graph = current_resource
	print( "regen_pending is now true (%d)" % [num_non_nodes_children])

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
			"position_offset" : node.position_offset / node.ui_scale,
			"name" : node.name,
			"template" : node.node_template,
			"settings" : node.settings,
			}
		#print( "Saving node %s" % [stored_data])
		current_resource.nodes.append(stored_data)

	for connection in gedit.get_connection_list():
		current_resource.conns.append( connection.duplicate() )

	current_resource.view_zoom = gedit.zoom
	current_resource.view_offset = gedit.scroll_offset
	current_resource.new_name_counter = new_name_counter
	
func _process(delta: float) -> void:
	if regen_pending and current_resource:
		#print( "Waiting %d == %d + %d (%d)" % [ gedit.get_child_count(), num_non_nodes_children, current_resource.nodes.size(), gedit_nodes_by_name.size()])
		if gedit.get_child_count() == num_non_nodes_children + current_resource.nodes.size():
			evalGraph()

func getNewName( suffix : String ):
	new_name_counter += 1
	return "id_%04d_%s" % [ new_name_counter, suffix ]

func registerNodeType( node_type_name, file ):
	var full_res_path = directory_path + "/" + file
	var loaded_class : Script = load( full_res_path ) as Script
	if not loaded_class:
		push_error("Failed to load class %s" % full_res_path )
		return
	var instance = loaded_class.new() as FlowNodeBase
	var meta = instance.getMeta()
	meta.factory = loaded_class
	#print( "Registering node type %s" % node_type_name )
	node_types[ node_type_name ] = meta

func scanAvailableNodes():
	var files := ResourceLoader.list_directory(directory_path) 
	for file in files:
		var stem = file.get_basename()
		if stem.ends_with("_settings"):
			continue
		registerNodeType( stem, file )

func populatePopupMenu():
	min_id = 1000
	max_id = min_id
	menu_ids = {}
	
	#gedit.theme.ac = Color( 1, 0.5, 0.5 );
	var pm := PopupMenu.new()
	add_child( pm )
	pm.name = "MainMenu"
	pm.clear();
	pm.add_item( "Clear", 0, KEY_NONE )
	pm.id_pressed.connect( _on_popup_menu_id_pressed )
	pm.add_separator( "", -1 )
	
	# A submenu to invoke the inputs declared in the pcg
	if current_resource && current_resource.inputs:
		var inputs_menu := PopupMenu.new()
		pm.add_child(inputs_menu)
		for idx in range(current_resource.inputs.inputs.size()):
			var label : String = current_resource.inputs.inputs[idx].name
			inputs_menu.add_item( FlowNodeBase.editorDisplayName( label ), idx)
		inputs_menu.id_pressed.connect( _on_inputs_menu_id_pressed )
		pm.add_submenu_item("Inputs...", inputs_menu.name)
		pm.add_separator( "", -1 )
	
	for key in node_types.keys():
		var node_type = node_types[ key ]
		var label = node_type.title
		max_id += 1
		if not node_type.get( "auto_register", true):
			print( "Adding menu %s skip (id:%d)" % [ label, max_id ])
			continue
		#print( "Adding menu %s -> %d" % [ label, max_id ])
		menu_ids[ max_id ] = key
		pm.add_item(label, max_id, KEY_NONE )
	return pm

func _ready():
	
	if not Engine.is_editor_hint():
		return
		
	ui_scale = 1.0
	var dpi = DisplayServer.screen_get_dpi()
	if dpi > 150:
		ui_scale *= 2.0
				
	scanAvailableNodes()
	
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
	
	%AutoRegen.button_pressed = auto_regen
	
func onNodePropertyChanged( prop_name : String):
	if inspected_node and inspected_node is FlowNodeBase:
		#print( "Node %s.%s has changed" % [ inspected_node.name, prop_name ])
		inspected_node.refreshFromSettings()
		queueRegen()
		
# ------------------------------------------------
func getSelectedFrames() -> Array[GraphFrame]:
	var nodes : Array[GraphFrame] = []
	for child in gedit.get_children():
		var node = child as GraphFrame
		if node and node.selected:
			nodes.push_back(node)
	return nodes

func deleteFrames( frames : Array[GraphFrame] ):
	for node in frames:
		gedit.remove_child( node )
		node.queue_free()
	
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
		gedit_nodes_by_name.erase( node.name )
		gedit.remove_child( node )
		node.queue_free()

func deleteSelectedNodes():
	
	var frames := getSelectedFrames()
	deleteFrames( frames )
	
	var nodes := getSelectedNodes()
	deleteNodes( nodes )
	saveResource()
	inspected_node = null
	inspector.edit(null)
	queueRegen()
	
	
func queueRegen():
	regen_pending = auto_regen
	
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

func addNodeFromTemplate( node_template, node_name : String, settings = null ):
	print( "addNode %s (%s : %s)" % [ node_template, node_name, str(settings) ])
	var node = packed_node.instantiate() as GraphNode
	var meta = node_types.get( node_template, null )
	if not meta:
		push_error("node_type %s is not registered" % node_template)
		print( node_types.keys() )
		return null	
	# print( "Meta:", str(meta) )
		
	node.set_script(meta.factory)

	node.node_template = node_template
	node.name = node_name
	node.ui_scale = ui_scale
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
	node.refreshFromSettings()
	gedit.add_child(node)
	gedit_nodes_by_name[ node.name ] = node
	return node
	
func addNode( node_template, settings = null ):
	var node_name = getNewName(node_template)
	var node = addNodeFromTemplate( node_template, node_name, settings )
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
	queueRegen()

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
			if not evt_key.ctrl_pressed and not evt_key.alt_pressed and not evt_key.shift_pressed:
				addComment()
		elif key == KEY_D:
			toggleDebug()
			evalGraph()
		elif key == KEY_E:
			toggleInspection()
			evalGraph()
			make_inspector_visible.call()
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
	
	inspected_node = node
	if inspected_node:
		if inspected_node is FlowNodeBase:
			inspector.edit( node.settings )
		elif inspected_node is GraphFrame:
			inspector.edit( inspected_node )
		
	#EditorInterface.inspect_object(node)
	#EditorInterface.set_main_screen_editor("3D")

func _on_graph_edit_popup_request(at_position):
	local_drop_position = at_position
	
	if not popup_menu:
		popup_menu = populatePopupMenu()
	var p = popup_menu
	p.size = Vector2( 400,200 )
	p.position = get_screen_position() + at_position
	p.popup()
	
func openAddMenu():
	var pos = get_local_mouse_position()
	_on_graph_edit_popup_request( pos )

func _on_inputs_menu_id_pressed(id: int) -> void:
	var input = current_resource.inputs.inputs[id]
	var node_type = "input_%s" % input.name
	print( "Creating a input node: %s (%d) -> %s" % [ input.name, input.data_type, node_type] )
	var settings := InputNodeSettings.new()
	settings.name = input.name
	settings.data_type = input.data_type
	addNode( node_type, settings )

func _on_popup_menu_id_pressed(id: int) -> void:
	if menu_ids.has( id ):
		var key = menu_ids[ id ]
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
	queueRegen()
	
func _on_graph_edit_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	gedit.disconnect_node(from_node, from_port, to_node, to_port)
	saveResource()
	queueRegen()

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
		if node.settings.inspect_enabled or node.settings.debug_enabled or node.getMeta().get( "is_final", false ):
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

func removeGeneratedNodes():
	# Remove instances from prev execution
	var nodes_to_remove = []
	for child in resource_owner.get_children():
		if child.has_meta( "flow_owner" ):
			nodes_to_remove.append(child)
	#print( "Removing %d generated comps" % [nodes_to_remove.size()])
	for child in nodes_to_remove:
		resource_owner.remove_child( child )
		child.queue_free()

func evalGraph():
	ctx.owner = resource_owner
	ctx.eval_id += 1
	
	var time_start = Time.get_ticks_usec()
	
	# print( "evalGraph %d starts from %s" % [ ctx.eval_id, resource_owner.name if resource_owner else "null" ] )
	removeGeneratedNodes()
	
	#print( "getEvalOrder..." )
	var nodes_to_eval = getEvalOrder( )
	for node in nodes_to_eval:
		#print( "  Eval: %s (%d)" % [ node.name, node.eval_id ] )
			
		# The node has already been evaluated
		if node.eval_id == ctx.eval_id:
			continue
		
		node.clearInputs()
		for req in node.deps:
			var req_node = gedit_nodes_by_name.get( req.from_node )
			var data = req_node.get_output( req.from_port )
			node.set_input( req.to_port, data )
			
		node.preExecute( ctx )
		node.execute( ctx )
		
		if node.settings.inspect_enabled:
			data_inspector.refresh()
		node.setupDebugDraw()

	regen_pending = false
	#print( "regen_pending is now false")
	
	var elapsed_usec = Time.get_ticks_usec() - time_start
	info.text = "%d evals in %.3f ms" % [ ctx.eval_id, elapsed_usec / 1000.0 ]

func _on_button_reload_pressed() -> void:
	scanAvailableNodes()
	popup_menu = null

func _on_button_save_pressed() -> void:
	if current_resource:
		ResourceSaver.save(current_resource)

func _on_button_regenerate_pressed() -> void:
	queueRegen()

func _on_auto_regen_toggled(toggled_on: bool) -> void:
	auto_regen = toggled_on

func _on_button_inputs_pressed():
	inspector.edit( current_resource.inputs )
	inspected_node = null
