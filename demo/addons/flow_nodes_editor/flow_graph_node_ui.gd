extends GraphNode
class_name FlowGraphNodeUI

var flow_node : FlowNodeBase

const enable_development_info := false 
const marker_radius : float = 9
const draw_node_name : bool = false
# Helper to create the UI
const connectors_row_prefab = preload( "res://addons/flow_nodes_editor/connectors_row.tscn" )
const connectors_options_prefab = preload( "res://addons/flow_nodes_editor/connectors_options.tscn" )

func _ready():
	ignore_invalid_connection_type = true
	updateStyle()

func redrawUI():
	queue_redraw()

func refreshDebugMark():
	redrawUI()

func refreshInspectMark():
	redrawUI()

func setFlowNode( new_node : FlowNodeBase ):
	if flow_node == new_node or ( flow_node == null and new_node != null ):
		flow_node = new_node 
		position_offset = flow_node.ui_position_offset
		flow_node.settings_changed.connect( regenerate )
		position_offset_changed.connect( on_moved )
		regenerate( StringName() )

func on_moved():
	if flow_node:
		flow_node.ui_position_offset = position_offset

func regenerate( PropName : StringName ):
	print( "node_ui.regenerate")
	if flow_node:
		var meta : Dictionary = flow_node.getMeta()
		self.tooltip_text = meta.get( "tooltip" )
		self.title = flow_node.getTitle()

func updateStyle():
	var sb = get_theme_stylebox("titlebar", "GraphNode").duplicate(true)
	var main_title_color = FlowNodeStyle.getCategoryColor( flow_node.getCategory() )
	sb.bg_color = main_title_color
	sb.set_content_margin_all(0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	add_theme_stylebox_override("titlebar", sb)
	sb = get_theme_stylebox("titlebar_selected", "GraphNode").duplicate(true)
	sb.bg_color = main_title_color
	sb.set_content_margin_all(0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	add_theme_stylebox_override("titlebar_selected", sb)

static func getColorForFlowDataType( data_type : FlowData.DataType ) -> Color:
	match( data_type ):
		FlowData.DataType.Bool:
			return Color.RED
		FlowData.DataType.Int:
			return Color.CYAN
		FlowData.DataType.Float:
			return Color.WEB_GREEN
		FlowData.DataType.Vector:
			return Color.BLUE_VIOLET
		FlowData.DataType.Color:
			return Color("eab308")
		FlowData.DataType.String:
			return Color.YELLOW
		FlowData.DataType.NodePath:
			return Color.SKY_BLUE
		FlowData.DataType.NodeMesh:
			return Color.MAGENTA
	return Color.WHEAT
	
func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip = preload("res://addons/flow_nodes_editor/resources/tooltip.tscn").instantiate()
	var meta : Dictionary = flow_node.getMeta()
	var extras : String = "\n\n" + str(flow_node.args_ports_by_name) if enable_development_info else ""
	var new_text := "[b]%s[/b] %s\n\n%s" % [
		meta.title, 
		flow_node.name,
		for_text + extras
		]
	tooltip.set_tooltip_text( new_text )
	return tooltip	
	
func _on_draw() -> void:
	
	if not flow_node:
		return

	var ui_scale := 1.0
	var err = flow_node.err
	
	if err:
		var sz = 16 * ui_scale
		draw_string( ThemeDB.fallback_font, Vector2(0,size.y + sz), err, HORIZONTAL_ALIGNMENT_LEFT, -1, sz )
		
	if flow_node.inspect_enabled:
		var clr : Color = Color.YELLOW / self_modulate
		draw_circle( Vector2(0,0), marker_radius * ui_scale, clr )
	if flow_node.debug_enabled:
		var clr : Color = Color.CYAN / self_modulate
		draw_circle( Vector2(size.x,0), marker_radius * ui_scale, clr )
	
	# Draw execution time badge (top-right, near titlebar)
	var exec_time_usec = get_meta("exec_time_usec", 0)
	if exec_time_usec > 100:
		var time_font = ThemeDB.fallback_font
		var time_font_size := int(11 * ui_scale)
		var time_text: String
		var time_color: Color
		if exec_time_usec >= 10000:  # > 10ms — warning
			time_text = "%.1f ms" % (exec_time_usec / 1000.0)
			time_color = Color(1.0, 0.6, 0.2, 0.9)  # Warm orange
		elif exec_time_usec >= 1000:  # 1-10ms
			time_text = "%.1f ms" % (exec_time_usec / 1000.0)
			time_color = Color(1, 1, 1, 0.4)
		else:
			time_text = "%d µs" % exec_time_usec
			time_color = Color(1, 1, 1, 0.25)
		var tw = time_font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, time_font_size).x
		var tx = size.x - tw - 8 * ui_scale
		var ty = size.y - 9.0 * ui_scale
		draw_string(time_font, Vector2(tx, ty), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, time_font_size, time_color)

	if draw_node_name:
		draw_string(ThemeDB.fallback_font, Vector2(2, -5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * ui_scale)


func initFromScript():
	
	if not flow_node:
		return
	
	var flow_editor = flow_node.getEditor()
	if flow_editor == null:
		return
	
	var meta : Dictionary = flow_node.getMeta()
	var trace = meta.get( "trace", false )
	
	if trace:
		print( "initFromScript: %s" % flow_node.getTitle())
	
	var ins = meta.get( "ins", [] )
	var outs = meta.get( "outs", [] )
	var num_ins = ins.size()
	var num_outs = outs.size()
	
	var exposed_params = flow_node.getExposedParams()
	if trace:
		print( "initFromScript.exposed_params: %s" % exposed_params.size())
	var has_exposed_params = exposed_params.size() > 0
	
	# Access to my parent container editor
	# We need to remember which nodes were connected as we might be expanded/contracting the list and want to 
	# maintain the same connected entries
	var connected_inputs_by_name = {}
	for arg_name in flow_node.args_ports_by_name:
		var arg_port = flow_node.args_ports_by_name[ arg_name ].port
		var curr_connections = flow_editor.get_connected_sources( name, arg_port )
		#print( "Checking if %s is connected at port %d -> %d conns" % [ arg_name, arg_port, curr_connections.size() ] )
		if not curr_connections.is_empty():
			connected_inputs_by_name[ arg_name ] = { "port" : arg_port, "conns" : curr_connections.duplicate() }
			for old_conn in curr_connections:
				var from_node = old_conn[0]
				var from_port = old_conn[1]
				flow_editor.disconnect_nodes( from_node, from_port, name, arg_port )
	
	if not flow_node.show_disconnected_inputs:
		exposed_params = exposed_params.filter( func( data ):
			return flow_node.args_ports_by_name.has( data.name ) and flow_node.args_ports_by_name[ data.name ].connected
		)
		
	if trace:
		print( "initFromScript: %s" % flow_node.getTitle())
		print( "  flow_editor: %s" % flow_editor)
		print( "  show_disconnected_inputs: %s" % flow_node.show_disconnected_inputs)
		print( "  all_exposed_params: %s" % exposed_params.size())
		print( "  exposed_params: %s" % exposed_params.size())
		print( "  args_ports_by_name: %s" % flow_node.args_ports_by_name)
		print( "  num_ins: %d num_outs: %d" % [num_ins, num_outs])
		
	# Total inputs are flow in streams + exposed parameters of the node
	var num_inputs = num_ins + exposed_params.size()
	flow_node.num_ports = max( num_inputs, num_outs )
	flow_node.num_in_ports = num_inputs
	flow_node.num_out_ports = num_outs
	
	# Delete current children
	clear_all_slots()
	for child in get_children():
		if child == flow_node.draw_debug:
			continue
		child.queue_free()
		remove_child( child )
	
	flow_node.args_ports_by_name = {}
	for idx in range( 0, flow_node.num_ports ):
		var ctrl = connectors_row_prefab.instantiate() as FlowConnectorRow
		add_child( ctrl )
		var lbl_in = ctrl.getInLabel()
		var lbl_out = ctrl.getOutLabel()
		
		# Is there an input active
		if idx < num_inputs:
			var in_data
			
			# Decide if it's a flow input, or just a param input
			if idx < num_ins:
				in_data = ins[idx]
			else:
				in_data = exposed_params[ idx - num_ins ]
			lbl_in.text = in_data.label
			
			var in_name = in_data.get( "name", in_data.label )
			
			set_slot_enabled_left( idx, true )
			
			# Change color
			var data_type = in_data.get( "data_type", FlowData.DataType.Invalid )
			if data_type == FlowData.DataType.Invalid and in_data.has( "type"):
				data_type = flow_node.getFlowDataTypeFromGdScriptType( in_data.type )
			if data_type != FlowData.DataType.Invalid:
				var color = getColorForFlowDataType( flow_node.data_type )	
				set_slot_color_left( idx, color )
				set_slot_type_left( idx, data_type )
			else:
				set_slot_type_left( idx,  FlowData.DataType.Any )
				
			in_data.port = idx
			ctrl.setData( in_data )
			
			flow_node.args_ports_by_name[ in_name ] = { "port" : idx, "connected" : connected_inputs_by_name.has( in_name ) }
			if trace:
				print( "%s : Assigning slot %d for input %s" % [ name, idx, in_name ])
		else:
			lbl_in.text = ""
			
		if idx < num_outs:
			var out_data = outs[idx]
			if out_data:
				lbl_out.text = out_data.label
				set_slot_enabled_right( idx, true )
					
				# Change color
				var data_type = out_data.get( "data_type", FlowData.DataType.Invalid )
				if data_type == FlowData.DataType.Invalid and out_data.has( "type"):
					data_type = flow_node.getFlowDataTypeFromGdScriptType( out_data.type )
				if data_type != FlowData.DataType.Invalid:
					var color = getColorForFlowDataType( data_type )	
					set_slot_color_right( idx, color )
					set_slot_type_right( idx, data_type )					
					
		else:
			lbl_out.text = ""
	
	# Add a button to show/hide all props and maybe more options in the future
	if has_exposed_params:
		var ctrl = connectors_options_prefab.instantiate() as FlowConnectorOptions
		ctrl.setShowDisconnectedInputs( flow_node.show_disconnected_inputs )
		ctrl.expand_toggled.connect( flow_node.nodeOptionsChanged )
		add_child( ctrl )

	# Force a readjust of the node in the flow editor
	size = get_combined_minimum_size()
	
	if trace:
		for arg_name in flow_node.args_ports_by_name.keys():
			print( "  %s : %s" % [ arg_name, flow_node.args_ports_by_name[ arg_name ] ] )
	
	# Reconnect nodes
	for arg_name in connected_inputs_by_name.keys():
		var old_data = connected_inputs_by_name[ arg_name ]
		var old_port = old_data.port
		
		# new_data might become invalid if the ins has changed
		var new_data = flow_node.args_ports_by_name.get( arg_name )
		if new_data:
			var new_port = new_data.port 
			for old_conn in old_data.conns:
				var from_node = old_conn[0]
				var from_port = old_conn[1]
				flow_editor.connect_nodes( from_node, from_port, name, new_port )
		flow_editor.queueSave()
	flow_editor.refreshSignalsInputArgs( self )
	
