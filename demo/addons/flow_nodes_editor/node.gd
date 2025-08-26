@tool
class_name FlowNodeBase
extends GraphNode

@export var settings: NodeSettings
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Common attributes
var inputs = []
var outputs = []

var args_ports_by_name = {}
var num_in_ports : int = 0
var num_out_ports : int = 0
var num_ports : int = 0			 # Max of (in,out)
var meta_node: Dictionary = {}

var node_template : String
var show_disconnected_inputs : bool = false

var dirty : bool = false

# Helper to create the UI
var connectors_row_prefab = preload( "res://addons/flow_nodes_editor/connectors_row.tscn" )
var connectors_options_prefab = preload( "res://addons/flow_nodes_editor/connectors_options.tscn" )

# Filled during runtime
var deps : Array[ Dictionary ]
var eval_id : int = 0
var err : String

# Render
var draw_debug : NodeDrawDebug
var ui_scale = 1.0
var marker_radius : float = 9

var debug_row : int = -1

func _ready():
	ignore_invalid_connection_type = true
	checkDrawDebug()
	refreshInspectMark()
	refreshDebugMark()
	
func checkDrawDebug():
	if not is_instance_valid(draw_debug) or draw_debug.get_parent() != self:
		draw_debug = NodeDrawDebug.new()
		draw_debug.node = self
		add_child(draw_debug)
		# if the helper gets freed, clear our reference
		draw_debug.tree_exited.connect(func(): draw_debug = null)
		
func setupDrawDebug():
	checkDrawDebug()
	draw_debug.setupDraw()
		
func set_output( idx : int, data ):
	if idx >= outputs.size():
		outputs.resize( idx + 1 )
	outputs[ idx ] = data

func set_input( idx : int, data ):
	if idx >= inputs.size():
		inputs.resize( idx + 1 )
	inputs[ idx ] = data
	
func clearInputs():
	for idx in range( inputs.size() ):
		inputs[ idx ] = null

func get_input( idx : int ):
	if idx >= inputs.size():
		push_error( "Input.%d does not exists in node %s" % [ idx, name ])
		return []
	return inputs[ idx ]

func get_optional_input( idx : int ):
	if idx >= inputs.size():
		return null
	return inputs[ idx ]
	
func get_optional_output( idx : int ):
	if idx >= outputs.size():
		return null
	return outputs[ idx ]

func get_output( idx : int ):
	if idx >= outputs.size():
		push_error( "Output.%d does not exists in node %s" % [ idx, name ])
		return []
	return outputs[ idx ]

func executedDisabled( ctx : FlowData.EvaluationContext ):
	if outputs.size() > 0 && inputs.size() > 0:
		var in_data = inputs[0]
		outputs.set( 0, in_data )

func preExecute( ctx : FlowData.EvaluationContext ):
	# clean outputs...
	eval_id = ctx.eval_id
	setError("")
	rng.seed = settings.random_seed

func redrawUI():
	queue_redraw()

func refreshDebugMark():
	redrawUI()

func refreshInspectMark():
	redrawUI()
	
func onPropChanged( prop_name : String ):
	dirty = true
	
func refreshFromSettings():
	refreshDebugMark()
	refreshInspectMark()
	title = getTitle()
	modulate = Color( 0.7, 0.7, 0.7, 0.5 ) if settings.disabled else Color.WHITE
	
	if ( not settings.debug_enabled and draw_debug ) or settings.disabled:
		draw_debug.cleanup_multimesh_direct()
	
func setError( new_err : String ):
	if new_err:
		push_error( "Node.Err %s : %s" % [ name, new_err ])
		editor_state_changed.emit()
	err = new_err
	redrawUI()
		
func _on_draw() -> void:
	
	if not settings:
		return

	if err:
		var sz = 16 * ui_scale
		self_modulate = Color(1.0, 0.5, 0.5)
		draw_string( ThemeDB.fallback_font, Vector2(0,size.y + sz), err, HORIZONTAL_ALIGNMENT_LEFT, -1, sz )
	else:
		self_modulate = Color.WHITE
		
	if settings.inspect_enabled:
		var clr : Color = Color.YELLOW / self_modulate
		draw_circle( Vector2(0,0), marker_radius * ui_scale, clr )
	if settings.debug_enabled:
		var clr : Color = Color.CYAN / self_modulate
		draw_circle( Vector2(size.x,0), marker_radius * ui_scale, clr )

func getMeta() -> Dictionary:
	return meta_node
	
func getTitle() -> String:
	return settings.title

func shuffleArray(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

static func editorDisplayName(property_name: String) -> String:
	var parts = property_name.split("_")
	for i in parts.size():
		parts[i] = parts[i].capitalize()
	return " ".join(parts)

static func getColorForGDScriptType( gd_type : int ) -> Color:
	match( gd_type ):
		TYPE_BOOL:
			return Color.RED
		TYPE_INT:
			return Color.CYAN
		TYPE_FLOAT:
			return Color.WEB_GREEN
		TYPE_VECTOR3:
			return Color.BLUE_VIOLET
		TYPE_STRING:
			return Color.YELLOW
		TYPE_NODE_PATH:
			return Color.SKY_BLUE
	return Color.WHEAT

static func getGdScriptTypeForFlowDataType( data_type : FlowData.DataType ) -> int:
	match( data_type ):
		FlowData.DataType.Bool:
			return TYPE_BOOL
		FlowData.DataType.Int:
			return TYPE_INT
		FlowData.DataType.Float:
			return TYPE_FLOAT
		FlowData.DataType.String:
			return TYPE_STRING
		FlowData.DataType.Vector:
			return TYPE_VECTOR3
	return TYPE_NIL
	
static func getFlowDataTypeFromGdScriptType( gd_type : int  ) -> FlowData.DataType:
	match( gd_type ):
		TYPE_BOOL:
			return FlowData.DataType.Bool
		TYPE_INT:
			return FlowData.DataType.Int
		TYPE_FLOAT: 
			return FlowData.DataType.Float
		TYPE_STRING:
			return FlowData.DataType.String 
		TYPE_VECTOR3:
			return FlowData.DataType.Vector
	return FlowData.DataType.Invalid

static func getFlowDataTypeFromObject( obj  ) -> FlowData.DataType:
	var data_type = getFlowDataTypeFromGdScriptType( typeof(obj) ) 
	if data_type != FlowData.DataType.Invalid:
		return data_type
	if obj is Resource:
		return FlowData.DataType.Resource
	return data_type

func exposedAsInputNode( prop ):
	return true

func get_exposed_params():
	var meta := getMeta()
	if meta.get( "hide_inputs", false ):
		return []
	var trace = meta.get( "trace", false )
	var my_title : String = meta.title
	var props = settings.get_property_list()
	var inside_my_vars := false
	var params = []
	for prop in props:
		if trace:
			print( "Input.", prop.name)
		if prop.name == "node_settings.gd":
			break
		if prop.name == "HiddenFromThisPoint":
			break
		if prop.name == my_title:
			inside_my_vars = true
		if !(prop.usage & PROPERTY_USAGE_STORAGE) || !(prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		if !inside_my_vars:
			continue
			
		var data = {
			"name" : prop.name,
			"label" : editorDisplayName( prop.name ),
			"type" : prop.type,
			"data_type" : getFlowDataTypeFromGdScriptType( prop.type ),
			"is_parameter" : true,
			"port" : -1,
		}
		
		if not exposedAsInputNode( data ):
			continue
		
		params.append( data )
	return params

func getEditor():
	var gedit = get_parent_control() as GraphEdit
	var flow_editor = gedit.get_parent_control().get_parent_control().get_parent_control() as FlowGraphEditor if gedit else null
	return flow_editor

func initFromScript():
	var meta := getMeta()
	var trace = meta.get( "trace", false )
	
	var ins = meta.get( "ins", [] )
	var outs = meta.get( "outs", [] )
	var num_ins = ins.size()
	var num_outs = outs.size()
	
	var exposed_params = get_exposed_params()
	var has_exposed_params = exposed_params.size() > 0
	
	# Access to my parent container editor
	# We need to remember which nodes were connected as we might be expanded/contracting the list and want to 
	# maintain the same connected entries
	var flow_editor = getEditor()
	var connected_inputs_by_name = {}
	if flow_editor:
		for arg_name in args_ports_by_name:
			var arg_port = args_ports_by_name[ arg_name ].port
			var curr_connections = flow_editor.get_connected_sources( name, arg_port )
			#print( "Checking if %s is connected at port %d -> %d conns" % [ arg_name, arg_port, curr_connections.size() ] )
			if not curr_connections.is_empty():
				connected_inputs_by_name[ arg_name ] = { "port" : arg_port, "conns" : curr_connections.duplicate() }
				for old_conn in curr_connections:
					var from_node = old_conn[0]
					var from_port = old_conn[1]
					flow_editor.disconnect_nodes( from_node, from_port, name, arg_port )
		
		if not show_disconnected_inputs:
			exposed_params = exposed_params.filter( func( data ):
				return args_ports_by_name.has( data.name ) and args_ports_by_name[ data.name ].connected
			)
	else:
		# When we just instantiate the node
		exposed_params = []
		
	if trace:
		print( "flow_editor: %s" % flow_editor)
		print( "show_disconnected_inputs: %s" % show_disconnected_inputs)
		print( "all_exposed_params: %s" % exposed_params.size())
		print( "exposed_params: %s" % exposed_params.size())
		print( "args_ports_by_name: %s" % args_ports_by_name)
		
	# Total inputs are flow in streams + exposed parameters of the node
	var num_inputs = num_ins + exposed_params.size()
	num_ports = max( num_inputs, num_outs )
	num_in_ports = num_inputs
	num_out_ports = num_outs
	
	# Delete current children
	self.get_input_port_count()
	clear_all_slots()
	for child in get_children():
		if child == draw_debug:
			continue
		child.queue_free()
		remove_child( child )
	
	args_ports_by_name = {}
	for idx in range( 0, num_ports ):
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
			if in_data.has( "type"):
				var color = getColorForGDScriptType( in_data.type )	
				set_slot_color_left( idx, color )
				set_slot_type_left( idx, in_data.type )
				
			in_data.port = idx
			ctrl.setData( in_data )
			
			args_ports_by_name[ in_name ] = { "port" : idx, "connected" : connected_inputs_by_name.has( in_name ) }
			if trace:
				print( "%s : Assigning slot %d for input %s" % [ name, idx, in_name ])
		else:
			lbl_in.text = ""
			
		if idx < num_outs:
			var out_data = outs[idx]
			if out_data:
				lbl_out.text = out_data.label
				set_slot_enabled_right( idx, true )
				if out_data.has( "type"):
					var color = getColorForGDScriptType( out_data.type )
					set_slot_color_right( idx, color )
					set_slot_type_right( idx, out_data.type )
		else:
			lbl_out.text = ""
	
	# Add a button to show/hide all props and maybe more options in the future
	if has_exposed_params:
		var ctrl = connectors_options_prefab.instantiate() as FlowConnectorOptions
		ctrl.setShowDisconnectedInputs( show_disconnected_inputs )
		ctrl.expand_toggled.connect( nodeOptionsChanged )
		add_child( ctrl )

	# Force a readjust of the node in the flow editor
	size = get_combined_minimum_size()
	
	if trace:
		for arg_name in args_ports_by_name.keys():
			print( "  %s : %s" % [ arg_name, args_ports_by_name[ arg_name ] ] )
	
	if flow_editor:
		# Reconnect nodes
		for arg_name in connected_inputs_by_name.keys():
			var old_data = connected_inputs_by_name[ arg_name ]
			var old_port = old_data.port
			var new_port = args_ports_by_name[ arg_name ].port
			for old_conn in old_data.conns:
				var from_node = old_conn[0]
				var from_port = old_conn[1]
				flow_editor.connect_nodes( from_node, from_port, name, new_port )
			flow_editor.queueSave()
		flow_editor.refreshSignalsInputArgs( self )
	
func refreshConnectionFlags( ):	
	var editor = getEditor()
	if editor:
		for arg_name in args_ports_by_name:
			args_ports_by_name[ arg_name ].connected = editor.is_node_port_connected( name, args_ports_by_name[ arg_name ].port )
		
func nodeOptionsChanged( expanded : bool ):
	show_disconnected_inputs = not show_disconnected_inputs
	refreshConnectionFlags( )
	initFromScript()
	setupDrawDebug()
	
# This returns the current value of the input configuration taking into account potencial connections and overrides of the inputs
func getSettingValue( ctx : FlowData.EvaluationContext, in_name : String ):
	var meta = getMeta()
	var trace = meta.get( "trace", false )
	
	var value = settings.get( in_name )
	if trace:
		print( "Searching the current value of input %s in %d inputs at node %s. ByName:%s vs %s.   Meta:%s" % [ in_name, inputs.size(), name, args_ports_by_name, inputs, meta ] )
	if args_ports_by_name.has( in_name ):
		var port = args_ports_by_name[ in_name ].port
		if port >= 0 and port < inputs.size():
			var input = inputs[ port ] as FlowData.Data
			if input:
				var in_streams = input.streams
				if trace:
					print( "Got the input for %s : %s" % [ in_name, in_streams.keys() ] )
				if in_streams and in_streams.size() == 1:
					var stream = in_streams.values()[0]
					var in_size = in_streams.size()
					if in_size == 0:
						setError( "Input %s has no data" % in_name)
					elif in_size > 1:
						setError( "Input %s has too many data (%d)" % [ in_name, in_size ])
					else:
						var new_value = stream.container[0]
						if trace:
							print( "  -> Using %s = %s" % [ in_name, new_value ])
						if typeof( new_value ) != typeof( value ):
							push_warning( "  Type of %s (%d) does not match the expected type (%d)" % [ in_name, typeof(new_value), typeof(value) ])
							
						return new_value
	return value

func newFloatStream( size : int, new_name : String, init_value ):
	var new_container = PackedFloat32Array()
	new_container.resize( size )
	if typeof(init_value) == TYPE_CALLABLE:
		var fn : Callable = init_value
		for idx in size:
			new_container[idx] = fn.call(idx)
	else:
		new_container.fill( init_value )
	return { 
		"data_type" : FlowData.DataType.Float,
		"container" : new_container,
		"name" : new_name
	}

func newVector3Stream( size : int, new_name : String, init_value ):
	var new_container = PackedVector3Array()
	new_container.resize( size )
	if typeof(init_value) == TYPE_CALLABLE:
		var fn : Callable = init_value
		for idx in size:
			new_container[idx] = fn.call(idx)
	else:
		new_container.fill( init_value )
	return { 
		"data_type" : FlowData.DataType.Vector,
		"container" : new_container,
		"name" : new_name
	}
