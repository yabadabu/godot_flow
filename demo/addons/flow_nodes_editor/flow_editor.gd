@tool
extends Control
class_name FlowGraphEditor

var current_resource: FlowGraphResource
var resource_owner : FlowGraphNode3D
var ctx := FlowData.EvaluationContext.new()
var regen_pending := false
var auto_regen := true
var dump_performance := false

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
var popup_menu_inputs : PopupMenu
var popup_on_over_input = null
const IDM_PROMOTE_TO_PARAMETER : int = 100

func setResourceToEdit( new_resource : FlowGraphResource, new_resource_owner : FlowGraphNode3D ):
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
		for input in current_resource.in_params:
			registerInputNodeType( input )
		
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
	ctx.owner = resource_owner
	print( "regen_pending is now true (%d)" % [num_non_nodes_children])
	populatePopupInputsMenu()

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

func registerInputNodeType( input ):
	var node_type_name := "input_%s" % input.name
	registerNodeType( node_type_name, "input.gd")

func scanAvailableNodes():
	var files := ResourceLoader.list_directory(directory_path) 
	for file in files:
		var stem = file.get_basename()
		if stem.ends_with("_settings"):
			continue
		registerNodeType( stem, file )

func populatePopupInputsMenu():
	if not popup_menu_inputs:
		return
	popup_menu_inputs.clear()

	if current_resource:
		for idx in range(current_resource.in_params.size()):
			var label : String = current_resource.in_params[idx].name
			popup_menu_inputs.add_item( FlowNodeBase.editorDisplayName( label ), idx)

	if popup_menu_inputs.get_item_count() == 0:
		popup_menu_inputs.add_item( "No inputs defined", -1 )
		popup_menu_inputs.set_item_disabled(0, true)

func populatePopupMenu():
	min_id = 1000
	max_id = min_id
	menu_ids = {}
	
	#gedit.theme.ac = Color( 1, 0.5, 0.5 );
	var pm := PopupMenu.new()
	add_child( pm )
	pm.name = "MainMenu"
	pm.clear();
	pm.id_pressed.connect( _on_popup_menu_id_pressed )
	#pm.add_item( "Clear", 0, KEY_NONE )
	#pm.add_separator( "", -1 )
	
	# A submenu to invoke the inputs declared in the pcg
	if popup_menu_inputs:
		popup_menu_inputs.queue_free()
	popup_menu_inputs = PopupMenu.new()
	popup_menu_inputs.name = "inputs_menu"
	popup_menu_inputs.id_pressed.connect( _on_inputs_menu_id_pressed )
	pm.add_child(popup_menu_inputs)
	pm.add_submenu_item("Inputs...", popup_menu_inputs.name)
	pm.add_separator( "", -1 )
	populatePopupInputsMenu()
	
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

func deleteGraphElementsAndRefresh( nodes : Array[GraphNode], frames : Array[GraphFrame] ):
	deleteFrames( frames )
	deleteNodes( nodes )
	saveResource()
	inspected_node = null
	inspector.edit(null)
	queueRegen()
	

func deleteSelectedNodes():
	var frames := getSelectedFrames()
	var nodes := getSelectedNodes()
	deleteGraphElementsAndRefresh( nodes, frames )
	
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

func setOnOverInParam( node, row ):
	#print( "On over %s.%s" % [ node.name, row.getInLabel().text ])
	popup_on_over_input = row

func clearOnOverInParam( ):
	popup_on_over_input = null

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
	
	for child in node.get_children():
		var row = child as FlowConnectorRow
		if not row or not row.isParameter():
			continue
		row.in_popup.connect( setOnOverInParam.bind( node, row ) )
		row.out_popup.connect( clearOnOverInParam)
	
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
	return node

# ------------------------------------------------
func _on_graph_edit_gui_input(event):
	var evt_key = event as InputEventKey
	if evt_key and evt_key.pressed:
		var no_modifiers = not evt_key.ctrl_pressed and not evt_key.alt_pressed and not evt_key.shift_pressed
		var key = evt_key.keycode
		if key == KEY_X or key == KEY_DELETE:
			if no_modifiers:
				deleteSelectedNodes()
		elif key == KEY_A:
			if no_modifiers:
				openAddMenu()
		elif key == KEY_C:
			if no_modifiers:
				addComment()
		elif key == KEY_D:
			if no_modifiers:
				toggleDebug()
				evalGraph()
		elif key == KEY_E:
			if no_modifiers:
				toggleInspection()
				evalGraph()
				make_inspector_visible.call()
		elif key == KEY_R:
			if no_modifiers:
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

func registerAsParameter( name : String, data_type : FlowData.DataType ):
	var new_input = GraphInputParameter.new()
	new_input.name = name
	new_input.data_type = data_type
	current_resource.in_params.append( new_input )
	registerInputNodeType( current_resource.in_params.back() )

func _on_in_popup_menu_pressed( id: int, row : FlowConnectorRow ) -> void:
	if id == IDM_PROMOTE_TO_PARAMETER and row:
		var node = row.getNode()
		print( "Promoting to parameter %s.%s (%s)" % [ node.name, row.getInLabel().text, row.data ] )
		var in_name = node.getMeta().title + " - " + row.data.in_label
		registerAsParameter( in_name, row.data.in_type )
		# Instantiate the input
		var new_input_node = _on_inputs_menu_id_pressed( current_resource.in_params.size() - 1 )
		if new_input_node:
			# Adjust the positions, the size is correct, our left is the parent left - size
			new_input_node.position_offset.x = node.position_offset.x - new_input_node.size.x - 40
			new_input_node.position_offset.y -= new_input_node.size.y - 15
			# Connect the input to the node
			_on_graph_edit_connection_request( new_input_node.name, 0, node.name, row.data.in_index )
		populatePopupInputsMenu()
		

func is_parameter( ) -> bool:
	return false
	
func _on_graph_edit_delete_nodes_request(node_names : Array[ String ]):
	print( "_on_graph_edit_delete_nodes_request", node_names )
	var frames : Array[ GraphFrame ]
	var nodes : Array[ GraphNode ]
	for node_name in node_names:
		var node = gedit.get_node( node_name )
		if not node:
			push_error( "Failed to find node %s to be deleted" % node_name)
			continue
		if node is GraphNode:
			nodes.append(node)
		elif node is GraphFrame:
			frames.append(node)
	deleteGraphElementsAndRefresh( nodes, frames )

func _on_graph_edit_popup_request(at_position):
	local_drop_position = at_position
	
	if popup_on_over_input:
		var node = popup_on_over_input.getNode()
		var pm := PopupMenu.new()
		add_child( pm )
		pm.name = "InPopupMenu"
		pm.add_item( "Promote To Parameter", IDM_PROMOTE_TO_PARAMETER, KEY_NONE )
		pm.id_pressed.connect( _on_in_popup_menu_pressed.bind( popup_on_over_input ) )
		pm.position = get_screen_position() + at_position + Vector2( 20, 20 )
		pm.popup()
		#print( "Show popup associated to %s.%s" % [ node.name, popup_on_over_input.getInLabel().text ] )
		return
	
	if not popup_menu:
		popup_menu = populatePopupMenu()
	var p = popup_menu
	p.size = Vector2( 400,200 )
	p.position = get_screen_position() + at_position
	p.popup()
	
func openAddMenu():
	var pos = get_local_mouse_position()
	_on_graph_edit_popup_request( pos )

func _on_inputs_menu_id_pressed(id: int):
	var input = current_resource.in_params[id]
	var node_type = "input_%s" % input.name
	print( "Creating a input node: %s (%d) -> %s" % [ input.name, input.data_type, node_type] )
	var settings := InputNodeSettings.new()
	settings.name = input.name
	settings.data_type = input.data_type
	return addNode( node_type, settings )

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
	# print( "_on_graph_edit_connection_request %s:%d <-> %s:%d" % [ from_node, from_port, to_node, to_port ] )
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
	ctx.eval_id += 1
	
	var time_start = Time.get_ticks_usec()
	
	# print( "evalGraph %d starts from %s" % [ ctx.eval_id, resource_owner.name if resource_owner else "null" ] )
	removeGeneratedNodes()
	
	var performance = []
	#print( "getEvalOrder..." )
	var nodes_to_eval = getEvalOrder( )
	for node in nodes_to_eval:
		#print( "  Eval: %s (%d)" % [ node.name, node.eval_id ] )
			
		# The node has already been evaluated
		if node.eval_id == ctx.eval_id:
			continue
		
		var time_node_start = Time.get_ticks_usec()
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
		var time_node_ends = Time.get_ticks_usec()
		
		if dump_performance:
			performance.append( { "name": node.name, "time": time_node_ends - time_node_start })

	regen_pending = false
	#print( "regen_pending is now false")
	
	var elapsed_usec = Time.get_ticks_usec() - time_start
	info.text = "%d evals in %.3f ms" % [ ctx.eval_id, elapsed_usec / 1000.0 ]
	if dump_performance:
		for entry in performance:
			var formatted := "%8.1s" % String.num(entry.time, 1)
			print( "%s usecs %s" % [ formatted, entry.name ] )
		dump_performance = false

func _on_button_reload_pressed() -> void:
	scanAvailableNodes()
	popup_menu = null

func _on_button_save_pressed() -> void:
	if current_resource:
		ResourceSaver.save(current_resource)

func _on_button_regenerate_pressed() -> void:
	dump_performance = true
	queueRegen()

func _on_auto_regen_toggled(toggled_on: bool) -> void:
	auto_regen = toggled_on

func _on_button_inputs_pressed():
	if current_resource:
		inspector.edit( current_resource )
	inspected_node = null

func _on_graph_edit_duplicate_nodes_request():
	print( "_on_graph_edit_duplicate_nodes_request" )

func resource_to_dict(resource: Resource) -> Dictionary:
	var dict := {}
	for prop in resource.get_property_list():
		if prop.name in FlowNodeAssets.discardted_props:
			continue
		if prop.usage & PROPERTY_USAGE_STORAGE != 0:
			var name = prop.name
			dict[name] = resource.get(name)
	return dict

func split_floats(in_str : String) -> Array:
	var parts = in_str.lstrip("(").rstrip(")").split(",")
	var vfloats = []
	for part in parts:
		vfloats.append( part.to_float() )
	return vfloats

func _parse_color(s: String) -> Color:
	var parts = split_floats(s)
	return Color(parts[0], parts[1], parts[2], parts[3])

func _parse_vector2(value) -> Vector2:
	var parts = split_floats(value)
	return Vector2(parts[0], parts[1])

func _parse_vector3(value) -> Vector3:
	var parts = split_floats(value)
	return Vector3(parts[0], parts[1], parts[2])

func dict_to_resource(data: Dictionary, resource: Resource) -> void:
	for prop in resource.get_property_list():
		var name = prop.name
		if name in FlowNodeAssets.discardted_props:
			continue
		if not data.has(name):
			continue
		var value = data[name]
		var type = prop.type
		match type:
			TYPE_COLOR:
				if typeof(value) == TYPE_STRING:
					resource.set(name, _parse_color(value))
				else:
					resource.set(name, value)
			TYPE_VECTOR2:
				resource.set(name, _parse_vector2(value))
			TYPE_VECTOR3:
				resource.set(name, _parse_vector3(value))
			_:
				resource.set(name, value)

func nodes_as_dict( nodes ):
	var exported_node_names = {}
	
	var min_pos = null
	for node in nodes:
		var pos = node.position_offset / ui_scale
		if min_pos == null:
			min_pos = pos
		else:
			min_pos.x = minf( min_pos.x, pos.x )
			min_pos.y = minf( min_pos.y, pos.y )
	
	var nodes_clean = nodes.map( func( node ):
		exported_node_names[ node.name ] = 1
		return {
			"position" : ( node.position_offset - min_pos ) / ui_scale,
			"name" : node.name,
			"template" : node.node_template,
			"settings" : resource_to_dict( node.settings ),
		}
	)
	var links = []
	for connection in gedit.get_connection_list():
		if connection.from_node in exported_node_names and connection.to_node in exported_node_names:
			links.append( connection )
	var data := {
		"type" : "flow_graph_nodes",
		"nodes" : nodes_clean,
		"links" : links
	}
	return data

func _on_graph_edit_copy_nodes_request():
	var nodes = getSelectedNodes()
	var json_str = JSON.stringify(nodes_as_dict(nodes), "\t")
	DisplayServer.clipboard_set( json_str )

func _on_graph_edit_cut_nodes_request():
	_on_graph_edit_copy_nodes_request()
	deleteSelectedNodes()

func _on_graph_edit_paste_nodes_request():
	print( "_on_graph_edit_paste_nodes_request" )
	var json_str = DisplayServer.clipboard_get( )
	var dict := JSON.parse_string(json_str)
	if typeof(dict) != TYPE_DICTIONARY:
		return
	if dict.get( "type", null) != "flow_graph_nodes":
		return
	var paste_offset : = Vector2( 100, 100 )
	var new_nodes = []
	var old_to_new_names = {}
	for in_node in dict.nodes:
		var in_name = in_node.name
		print( "Recreating %s" % in_node )
		var new_name = getNewName(in_node.template)
		var node = addNodeFromTemplate( in_node.template, new_name )
		if not node:
			return null
		var in_pos = _parse_vector2( in_node.position )
		node.position_offset = ( in_pos + paste_offset ) * ui_scale
		
		# Apply saved settings...
		dict_to_resource( in_node.settings, node.settings )
		
		# Update relation old -> new for the links
		old_to_new_names[ in_name ] = new_name
		new_nodes.append( node )
		
	print( "Dict nmes", old_to_new_names )
	
	for link in dict.links:
		var new_from = old_to_new_names.get( link.from_node, null )
		var new_to = old_to_new_names.get( link.to_node, null )
		if new_from == null or new_to == null:
			print( "Failed to identify params links", link)
			continue
		gedit.connect_node(new_from, link.from_port, new_to, link.to_port )

	# Update selection
	for node in getSelectedNodes():
		node.selected = false
	for node in new_nodes:
		node.selected = true
