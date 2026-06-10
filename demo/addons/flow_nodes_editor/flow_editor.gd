@tool
extends Control
class_name FlowGraphEditor

# This is the main container of the DataFlow Graph Editor

var current_resource: FlowGraphResource
var resource_owner : FlowGraphNode3D
var ctx := FlowData.EvaluationContext.new()
var regen_pending := false
var save_pending := false
var auto_regen := true
var dump_performance := false

@onready var tab_bar: TabBar = %TabBar
var open_tabs: Array[Dictionary] = []

@onready var gedit : GraphEdit = %GraphEdit
@onready var data_inspector : Control
@onready var info : Label = %LabelInfo

# The inspector shows the settings property of the current node
var inspector: EditorInspector
var inspected_node : Node
var make_inspector_visible : Callable
var search_add_node_popup: SearchAddNodePopup

# This is the default graph-node instantiated, the script contains the logic
var packed_node = preload("res://addons/flow_nodes_editor/node.tscn")
var packed_search_add_node_popup = preload("res://addons/flow_nodes_editor/search_add_node_popup.tscn")
const directory_path := "res://addons/flow_nodes_editor/nodes"

# New nodes generation using the editor
var local_drop_position : Vector2 = Vector2(0,0)
var auto_connect_from_node : String
var auto_connect_from_port : int
var auto_connect_to_node : String
var auto_connect_to_port : int

# Ranges for the menu
var min_id = 1000
var max_id = min_id
var menu_ids : Dictionary = {}

var comment_padding = Vector2( 40, 40 )

# Required during evaluation
var gedit_nodes_by_name = {}
var input_sources := {} # key: Pair(to_node, to_port) -> value: Array[(from_node, from_port)]

# Activate connections and nodes
var active_intensity = 0.0
var active_nodes = []

var ui_scale = 1.0
var nodes_factory = FlowNodesFactory.new()

var popup_menu_inputs : PopupMenu
var popup_on_over_input = null
const IDM_PROMOTE_TO_PARAMETER : int = 100

func setResourceToEdit( new_resource : FlowGraphResource, new_resource_owner : FlowGraphNode3D ):
	print( "setResourceToEdit %s" % new_resource )
	var tab_idx = findIndexInTabs( new_resource )
	if tab_idx < 0:
		tab_idx = addToTabs( new_resource, new_resource_owner )
	tab_bar.ensure_tab_visible( tab_idx )
	tab_bar.current_tab = tab_idx

	# Time to save the current resource
	if current_resource == new_resource and resource_owner == new_resource_owner:
		return
	if current_resource:
		current_resource.in_params_changed.disconnect(_on_inputs_changed)
		saveResource()
	current_resource = new_resource
	if current_resource:
		current_resource.in_params_changed.connect(_on_inputs_changed)
	resource_owner = new_resource_owner
	
	# Remove exiting nodes
	var children = []
	for child in gedit.get_children():
		if child is GraphNode or child is GraphFrame:
			child.queue_free()
			children.append( child )
	
	input_sources.clear()
	gedit.clear_connections()
	for child in children:
		gedit.remove_child( child )
	
	gedit_nodes_by_name.clear()
	inspector.edit( null )
	inspected_node = null
	
	FlowNodeIO.loadFromResource( self )
	
	ctx.graph = current_resource
	ctx.owner = resource_owner
	ctx.gedit_nodes_by_name = gedit_nodes_by_name
	markAllNodesAsDirty()
	queueRegen()

func saveResource():
	FlowNodeIO.saveToResource( self )
	save_pending = false
	
func asInputNode( in_node : Node ):
	var node := in_node as GraphNode
	return node if node and node.node_template.begins_with("input") else null

func _on_inputs_changed():
	for child in gedit.get_children():
		var node = asInputNode( child )
		if node:
			var in_name = node.settings.name
			var curr_input = current_resource.findInParamByName(in_name)
			if curr_input and curr_input.is_constant:
				var new_value = curr_input.get_default_value()
				#print( "Checking name %s -> %s" % [ in_name, new_value ] )
				if node.last_value_pushed and new_value == node.last_value_pushed:
					continue
				else:
					#print( "Changed from %s to %s" % [ node.last_value_pushed, new_value ] )
					node.settings.data_type = curr_input.getDataType()
					node.dirty = true
					node.refreshFromSettings()
					queueRegen()
			
func _process(delta: float) -> void:
	if not current_resource:
		return
		
	if save_pending:
		saveResource()
		
	# This is also trigered to true by plugin.gd:_on_history_changed
	if regen_pending:
		#print( "_process.regen_pending: %s" % [ regen_pending ])
		evalGraph()

	# Update active connections
	elif active_intensity > 0.0:
		active_intensity -= 0.016 * 4
		if active_intensity < 0:
			active_intensity = 0.0
		for node in active_nodes:
			node.setActivity( active_intensity )
			
		if active_intensity == 0:
			active_nodes.clear()
		gedit.queue_redraw()

func _ready():
	
	if not Engine.is_editor_hint():
		return
		
	ui_scale = 1.0
	var dpi = DisplayServer.screen_get_dpi()
	if dpi > 150:
		ui_scale *= 2.0
				
	nodes_factory.scanAvailableNodes()
	
	inspector = EditorInspector.new()
	inspector.custom_minimum_size = Vector2( 200, 600 )
	var splitter = $VBoxContainer/VSplitContainer
	splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.add_child( inspector )
	splitter.split_offset = 300
	
	gedit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gedit.size_flags_vertical = Control.SIZE_EXPAND_FILL	
	gedit.add_theme_color_override("activity", Color(1, 0.2, 0.2, 1))
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.custom_minimum_size.y = 150
	inspector.property_edited.connect( onNodePropertyChanged )
	
	# Instantiate custom SearchAddNodePopup
	search_add_node_popup = packed_search_add_node_popup.instantiate() as SearchAddNodePopup
	add_child(search_add_node_popup)
	search_add_node_popup.node_selected.connect(_on_search_add_node_popup_node_selected)
	search_add_node_popup.input_selected.connect(_on_search_add_node_popup_input_selected)
	search_add_node_popup.action_selected.connect(_on_search_add_node_popup_action_selected)
	search_add_node_popup.on_closed.connect( func():
		auto_connect_from_node = ""
		auto_connect_to_node = ""
		)
	%AutoRegen.button_pressed = auto_regen
	
func onNodePropertyChanged( prop_name : String):
	if inspected_node and inspected_node is FlowNodeBase:
		#print( "Node %s.%s has changed" % [ inspected_node.name, prop_name ])
		inspected_node.onPropChanged( prop_name )
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
		for n in range( node.num_ports ):
			remove_all_inputs_to_target_connection( node.name, n )
		for n in range( node.getMeta().outs.size() ):
			remove_all_inputs_to_source_connection( node.name, n )
		gedit_nodes_by_name.erase( node.name )
		gedit.remove_child( node )
		node.queue_free()

func deleteGraphElementsAndRefresh( nodes : Array[GraphNode], frames : Array[GraphFrame] ):
	deleteFrames( frames )
	deleteNodes( nodes )
	queueSave()
	inspected_node = null
	inspector.edit(null)
	removeGeneratedNodes( null )
	queueRegen()
	
func deleteSelectedNodes():
	var frames := getSelectedFrames()
	var nodes := getSelectedNodes()
	deleteGraphElementsAndRefresh( nodes, frames )
	
func queueSave():
	save_pending = true
	
func queueRegen():
	#print( "queueRegen -> %s" % [ auto_regen ])
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

func localToGraphCoords( local_coords : Vector2 ):
	#var view_zero_in_scroll_offset = gedit.scroll_offset / gedit.zoom
	return ( gedit.scroll_offset + local_coords ) / gedit.zoom

func setOnOverInParam( row ):
	popup_on_over_input = row
	
func refreshSignalsInputArgs( node ):
	for child in node.get_children():
		var row = child as FlowConnectorRow
		if not row or not row.isParameter():
			continue
		if row.in_popup.get_connections().is_empty():
			row.in_popup.connect( setOnOverInParam.bind( row ) )
		if row.out_popup.get_connections().is_empty():
			row.out_popup.connect( setOnOverInParam.bind( null ) )	

func addNodeFromTemplate( node_template, node_name : String, settings = null ):
	if gedit_nodes_by_name.has( node_name ):
		node_name = nodes_factory.getNewName(node_template)
	var node = nodes_factory.createNewNode( packed_node, node_template, node_name, settings )
	if node:
		node.ui_scale = ui_scale
		node.position_offset = localToGraphCoords(local_drop_position)
		refreshSignalsInputArgs( node )
		gedit.add_child(node)
		gedit_nodes_by_name[ node.name ] = node
	return node
	
func canConnect( src : FlowNodeBase, src_port : int, dst : FlowNodeBase, dst_port : int ):
	# Discard self connections and null values
	if dst == src or src == null or dst == null:
		push_warning( "canConnect. Invalid inputs: ", src, " <-> ", dst )
		return false
		
	# Check Slot numbers
	if dst_port >= dst.num_in_ports:
		push_warning( "canConnect. dst_port(%d) >= num_in_ports(%d) dst:%s" % [ dst_port, dst.num_in_ports, dst.name ])
		return false
	if src_port >= src.num_out_ports:
		push_warning( "canConnect. src_port(%d) >= num_out_ports(%d) src:%s" % [ src_port, src.num_out_ports, src.name ])
		return false
		
	var src_type = src.get_output_port_type( src_port )
	var dst_type = dst.get_input_port_type( dst_port )
	if (src_type and dst_type) or (src_type == FlowData.DataType.NodePath) or (src_type == FlowData.DataType.NodeMesh):
		if src_type != dst_type:
			push_warning( "Node types do not match %d vs %d" % [ src_type, dst_type ])
			return false
		
	#print( "canConnect OK %s:%d (%d)-> %s:%d (%d)" % [ src.name, src_port, src_type, dst.name, dst_port, dst_type ] )
	return true
	
func addNode( node_template, settings = null ):
	var node_name = nodes_factory.getNewName(node_template)
	var node = addNodeFromTemplate( node_template, node_name, settings )
	if not node:
		return null
		
	if auto_connect_from_node:
		var source_node = gedit_nodes_by_name.get( auto_connect_from_node )
		if canConnect( source_node, auto_connect_from_port, node, 0 ):
			connect_nodes(auto_connect_from_node, auto_connect_from_port, node.name, 0)
		
	if auto_connect_to_node:
		var target_node = gedit_nodes_by_name.get( auto_connect_to_node )
		if canConnect( node, 0, target_node, auto_connect_to_port ):
			connect_nodes(node.name, 0, auto_connect_to_node, auto_connect_to_port )
	
	for prev_node in getSelectedNodes():
		prev_node.selected = false
	node.selected = true
	node.visible = true
	queueSave()
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
			if evt_key.shift_pressed:
				openAddMenu()
			else:
				if no_modifiers:
					toggleInspection()
					evalGraph()
					make_inspector_visible.call()
		elif key == KEY_C:
			if no_modifiers:
				addComment()
		elif key == KEY_D:
			if no_modifiers:
				toggleDebug()
				evalGraph()
		elif key == KEY_E:
			if no_modifiers:
				toggleDisabled()
				evalGraph()
		elif key == KEY_R:
			if no_modifiers:
				for node in getSelectedNodes():
					node.dirty = true
				evalGraph()

func toggleDebug():
	var nodes = getSelectedNodes()
	for node in nodes:
		node.dirty = true
		node.settings.debug_enabled = !node.settings.debug_enabled
		node.refreshFromSettings()

func toggleDisabled():
	var nodes = getSelectedNodes()
	for node in nodes:
		node.dirty = true
		node.settings.disabled = !node.settings.disabled
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
	node.dirty = true
	node.refreshFromSettings()

func addComment():
	var nodes = getSelectedNodes()
	var rect = getRectOfNodes( nodes )
	rect.position -= comment_padding
	rect.size += comment_padding * 2
	
	var frame := GraphFrame.new()
	frame.name = nodes_factory.getNewName("comment")
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

func _on_in_popup_menu_pressed( id: int, row : FlowConnectorRow ) -> void:
	if id == IDM_PROMOTE_TO_PARAMETER and row:
		var node = row.getNode()
		print( "Promoting to parameter %s.%s (%s)" % [ node.name, row.getInLabel().text, row.data ] )
		var in_name = node.getMeta().title + " - " + row.data.label
		registerAsParameter( in_name, row.data.data_type )
		# Instantiate the input
		var new_input_node = _on_search_add_node_popup_input_selected( current_resource.in_params.size() - 1 )
		if new_input_node:
			# Adjust the positions, the size is correct, our left is the parent left - size
			new_input_node.position_offset.x = node.position_offset.x - new_input_node.size.x - 40
			new_input_node.position_offset.y -= new_input_node.size.y - 15
			# Connect the input to the node
			_on_graph_edit_connection_request( new_input_node.name, 0, node.name, row.data.port )
		
func _on_graph_edit_delete_nodes_request(node_names : Array):
	print( "_on_graph_edit_delete_nodes_request: ", node_names )
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
		
	var required_input_type := FlowData.DataType.Invalid
	var required_output_type := FlowData.DataType.Invalid
	if auto_connect_from_node:
		var from_node = gedit_nodes_by_name.get( auto_connect_from_node )
		if from_node:
			var meta = from_node.getMeta()
			var oport = meta.outs[ auto_connect_from_port ]
			required_input_type = oport.get( "data_type", FlowData.DataType.Invalid )
		print( "auto_connect_from_node: %s:%d -> %d" % [ auto_connect_from_node, auto_connect_from_port, required_input_type])
		
	if auto_connect_to_node:
		var to_node = gedit_nodes_by_name.get( auto_connect_to_node )
		if to_node:
			var meta = to_node.getMeta()
			print( "Autoconnecting to %s : %d gives %s" %[ auto_connect_to_node, auto_connect_to_port, meta ])
			if auto_connect_to_port < meta.ins.size():
				var iport = meta.ins[ auto_connect_to_port ]
				required_output_type = iport.get( "data_type", FlowData.DataType.Invalid )
			else:
				print( "  Autoconnect is connecting to a cte of the node")
				var exposed_params = to_node.getExposedParams()
				print( "  exposed_params", exposed_params)
				var exposed_index = auto_connect_to_port - meta.ins.size()
				var iport = exposed_params[ exposed_index ]
				required_output_type = iport.get( "data_type", FlowData.DataType.Invalid )
		print( "auto_connect_to_node: %s:%d -> %d" % [auto_connect_to_node, auto_connect_to_port, required_output_type ])
		
	var in_params = []
	var out_params = []
	if current_resource:
		in_params = current_resource.in_params
		
	search_add_node_popup.setup( nodes_factory.node_types, in_params, out_params, required_input_type, required_output_type )
	search_add_node_popup.appearAt(get_screen_position() + at_position)
	
	
func openAddMenu():
	var pos = get_local_mouse_position()
	_on_graph_edit_popup_request( pos )

func _on_search_add_node_popup_node_selected(template_name : String):
	addNode(template_name)

func _on_search_add_node_popup_input_selected(id : int):
	var input = current_resource.in_params[id]
	var node_type = "input_%s" % input.name
	print( "Creating an input node: %s (%d) -> %s" % [ input.name, input.data_type, node_type] )
	var settings := InputNodeSettings.new()
	settings.name = input.name
	settings.data_type = input.data_type
	return addNode( node_type, settings )

func _on_search_add_node_popup_action_selected(action_id : int):
	if action_id == SearchAddNodePopup.ACTION_ADD_NEW_INPUT:
		current_resource.in_params.append(GraphInputParameter.new())
		inspector.edit(null)		# To force a refresh
		_on_button_inputs_pressed()

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
	
func addFrame( frame_data : Dictionary, old_to_new_names : Dictionary, paste_offset  ):
	var frame := GraphFrame.new()
	frame.name = frame_data.name
	frame.title = frame_data.title
	var in_pos = FlowNodeIO._parse_vector2( frame_data.position )
	frame.position_offset = (in_pos + paste_offset ) * ui_scale
	frame.size = FlowNodeIO._parse_vector2( frame_data.size )
	frame.tint_color = FlowNodeIO._parse_color( frame_data.tint_color )
	frame.tint_color_enabled = true
	gedit.add_child(frame)
	for old_name in frame_data.attached:
		var new_name = old_to_new_names.get( old_name, null )
		if new_name:
			gedit.attach_graph_element_to_frame( new_name, frame.name )

func disconnect_nodes(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	#print( "disconnect_nodes From:%s:%d To:%s:%d" % [ from_node, from_port, to_node, to_port ])
	gedit.disconnect_node(from_node, from_port, to_node, to_port)
	remove_input_source_target_connection( from_node, from_port, to_node, to_port )

	var dst_node : FlowNodeBase = gedit_nodes_by_name.get( to_node )
	if dst_node != null:
		dst_node.dirty = true
	
func connect_nodes(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	#print( "connect_nodes %s:%d -> %s:%d" % [ from_node, from_port, to_node, to_port ] )
	gedit.connect_node(from_node, from_port, to_node, to_port)
	var key = [to_node, to_port]
	if not input_sources.has(key):
		input_sources.set( key, [])
	input_sources[key].append([from_node, from_port])

	var dst_node : FlowNodeBase = gedit_nodes_by_name.get( to_node )
	if dst_node != null:
		dst_node.dirty = true


func findConnectionToNodeAndPort( node : FlowNodeBase, in_port : int ):
	for conn in node.deps:
		if conn.to_port == in_port:
			return conn
	return null

func _on_graph_edit_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node = gedit_nodes_by_name.get( from_node )
	var dst_node = gedit_nodes_by_name.get( to_node )
	if not canConnect( src_node, from_port, dst_node, to_port ):
		return
	#print( "Conn request")
	#print( "  from %s" % src_node )
	#print( "    to %s" % dst_node )
	
	# Check if the input does not allow multiple connections
	var to_port_meta = dst_node.getMeta().ins[ to_port ] if to_port < dst_node.getMeta().ins.size() else {}
	if not to_port_meta.get( "multiple_connections", true ):
		var conn = findConnectionToNodeAndPort( dst_node, to_port )
		if conn != null:
			disconnect_nodes( conn.from_node, conn.from_port, conn.to_node, conn.to_port )
	
	connect_nodes( from_node, from_port, to_node, to_port )
	queueSave()
	queueRegen()
	
func get_connected_sources(to_node: StringName, to_port: int) -> Array:
	return input_sources.get([to_node, to_port], [])
	
func is_node_port_connected( to_node: StringName, to_port: int ) -> bool:
	return not input_sources.get([to_node, to_port], []).is_empty()
	
func remove_input_source_target_connection( from_node: StringName, from_port: int, to_node : StringName, to_port : int ):
	var key = [to_node, to_port]
	if key in input_sources:
		input_sources[key].erase([from_node, from_port])
		if input_sources[key].is_empty():
			input_sources.erase(key)
	
func remove_all_inputs_to_target_connection( to_node : StringName, to_port : int ):
	var key = [to_node, to_port]
	if key in input_sources:
		input_sources.erase(key)
	
func remove_all_inputs_to_source_connection( from_node : StringName, from_port : int ):
	var conns_to_delete = []
	for key in input_sources.keys():
		for src in input_sources[ key ]:
			if src[0] == from_node && src[1] == from_port:
				conns_to_delete.append( [ src[0], src[1], key[0], key[1] ] )
	for conn in conns_to_delete:
		remove_input_source_target_connection( conn[0], conn[1], conn[2], conn[3])
	
func _on_graph_edit_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	disconnect_nodes(from_node, from_port, to_node, to_port)
	queueSave()
	queueRegen()

func _on_graph_edit_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	auto_connect_from_node = from_node
	auto_connect_from_port = from_port
	auto_connect_to_node = ""
	local_drop_position = release_position
	_on_graph_edit_popup_request( local_drop_position )

func _on_graph_edit_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	auto_connect_to_node = to_node
	auto_connect_to_port = to_port
	auto_connect_from_node = ""
	local_drop_position = release_position
	_on_graph_edit_popup_request( local_drop_position )

func getAllNodes() -> Array[ FlowNodeBase ]:
	var nodes : Array[ FlowNodeBase ] = []
	for child in gedit.get_children():
		var node = child as FlowNodeBase
		if not node:
			continue
		nodes.append( node )
	return nodes

func removeGeneratedNodes( flow_owner ):
	if not resource_owner:
		return
	# Remove instances from prev execution
	var nodes_to_remove = []
	for child in resource_owner.get_children():
		if child.has_meta( "flow_owner" ):
			if not flow_owner or flow_owner ==child.get_meta( "flow_owner" ): 
				nodes_to_remove.append(child)
	#print( "Removing %d generated comps" % [nodes_to_remove.size()])
	for child in nodes_to_remove:
		resource_owner.remove_child( child )
		child.queue_free()

func getDirtyNodes() -> Array[ FlowNodeBase ]:
	return getAllNodes().filter( func( node : FlowNodeBase ) -> bool:
		return node.dirty 
	)

func cacheConnections():
	
	# Clear all the arrays
	var nodes := getAllNodes()
	for node in nodes:
		node.deps.clear()
		node.dependants.clear()
			
	# Add each connection to left and right sides
	for conn in gedit.connections:
		var src_node = gedit_nodes_by_name.get( conn.from_node )
		var dst_node = gedit_nodes_by_name.get( conn.to_node )
		if src_node and dst_node:
			src_node.dependants.append( conn )
			dst_node.deps.append( conn )

	#for node in getAllNodes():
		#print( "Node: %s" % [ node.name ])
		#print( "  deps: %s" % [ node.deps ])
		#print( "  dependants: %s" % [ node.dependants ])

func expandDirtyFlagToDependants( node : FlowNodeBase ):
	#print( "%s is dirty" % [ node.name ] )
	for out_conn in node.dependants:
		#print( "  -> %s" % [ out_conn ])
		var dst_node = gedit_nodes_by_name.get( out_conn.to_node )
		if dst_node:
			if not dst_node.dirty:
				dst_node.dirty = true
				expandDirtyFlagToDependants( dst_node )

func evalGraph():
	
	var time_start = Time.get_ticks_usec()
	
	# print( "evalGraph %d starts from %s" % [ ctx.eval_id, resource_owner.name if resource_owner else "null" ] )
	#removeGeneratedNodes()
	
	cacheConnections()
	
	active_intensity = 1.0
	active_nodes.clear()
	
	var dirty_nodes := getDirtyNodes()
	for node in dirty_nodes:
		expandDirtyFlagToDependants( node )
	dirty_nodes = getDirtyNodes()
	#for node in dirty_nodes:
		#print( "Dirty: %s" % node.name )
	
	var performance = []
	#print( "getEvalOrder..." )
	ctx.nodes_to_eval = ctx.getEvalOrder( getAllNodes() )
	ctx.run()
	active_nodes = ctx.active_nodes
	
	for node in active_nodes:
		if node.settings.inspect_enabled:
			data_inspector.refresh()
		node.setupDrawDebug()
		if dump_performance:
			performance.append( { "name": node.name, "time": node.get_meta("exec_time_usec", 0) })

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
	nodes_factory.scanAvailableNodes()

func _on_button_save_pressed() -> void:
	if current_resource:
		saveResource()
		ResourceSaver.save(current_resource)

func markAllNodesAsDirty():
	for node in getAllNodes():
		node.dirty = true	

func _on_button_regenerate_pressed() -> void:
	#for key in input_sources.keys():
		#print( key )	
		#for val in input_sources[ key ]:
			#print( "  %s" % [ val ] )	
	#for conn in gedit.connections:
		#print( conn )
	dump_performance = true
	markAllNodesAsDirty()
	queueRegen()
	#for n : FlowNodeBase in getSelectedNodes():
		#print( "Node: %s  Ins:%d  Outs:%d" % [ n.name, n.num_in_ports, n.num_out_ports ])
		#for idx in range( n.num_in_ports ):
			#var type = n.get_slot_type_left( idx )
			#print( "Left.%d = %d" % [ idx, type ] )

func _on_auto_regen_toggled(toggled_on: bool) -> void:
	auto_regen = toggled_on

func _on_button_inputs_pressed():
	if current_resource:
		inspector.edit( current_resource )
	inspected_node = null

# Cut/Copy/Paste/Dupe
func _on_graph_edit_copy_nodes_request():
	FlowNodeIO.copySelectionToClipboard( self )

func _on_graph_edit_cut_nodes_request():
	_on_graph_edit_copy_nodes_request()
	deleteSelectedNodes()

func _on_graph_edit_paste_nodes_request():
	FlowNodeIO.pasteNodeFromClipboard( self )

func _on_graph_edit_duplicate_nodes_request():
	FlowNodeIO.duplicateSelecteddNodes( self )
	
func onEditorSceneChanged():
	# When a node in the scene changes, just mark dirty all nodes
	# which can potentially become dirty
	# This also triggers as dirty all scan_* nodes when we change
	# anything in another of our nodes. Not very good
	for node in getAllNodes():
		if node.getMeta().get( "scans_scene", false ):
			node.dirty = true
	queueRegen()

# new_resource = res://graph02_curves.tres
# title = graph02_curves
func addToTabs(  new_resource : FlowGraphResource, new_resource_owner : FlowGraphNode3D ):
	var title = new_resource.resource_path.get_file().get_basename()
	var dtab : Dictionary = {
		resource = new_resource,
		owner = new_resource_owner,
		title = title
	}
	open_tabs.append( dtab )
	tab_bar.add_tab( title )
	return tab_bar.tab_count - 1

func findIndexInTabs( resource ) -> int:
	for idx in range(open_tabs.size()):
		var dtab = open_tabs[idx]
		if dtab.resource == resource:
			return idx
	return -1

func _on_tab_bar_tab_close_pressed(tab_idx):
	open_tabs.remove_at( tab_idx )
	tab_bar.remove_tab( tab_idx )

func _on_tab_bar_tab_changed(tab_idx):
	var dtab = open_tabs[ tab_idx ] if tab_idx < open_tabs.size() else null
	if dtab:
		setResourceToEdit( dtab.resource, dtab.owner )
