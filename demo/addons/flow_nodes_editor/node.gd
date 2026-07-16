@tool
class_name FlowNodeBase
extends Resource

# This represent the base class for all nodes in the flow graph
# The actual nodes are implemented in the nodes subfolder

enum eDebugMode {
	EXTENDS,
	ABSOLUTE,
}

@export_group("Common Settings")
@export var name : StringName
@export var title : String
@export var random_seed: int = 12345

@export var inspect_enabled: bool = false

@export var debug_enabled: bool = false
@export var debug_mode : eDebugMode = eDebugMode.EXTENDS
@export var debug_scale : float = 1.0
@export var debug_output: int = 0
@export var debug_bulk: int = 0
@export var debug_port_combined_index: int = 0

@export var debug_color : Color = Color.WHITE
@export var debug_modulate_by : String

# Add any other common properties here
@export var disabled: bool = false
@export var trace: bool = false

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Common attributes ------------------------------
var num_connected_bulks : int = 0
var input_bulks : Array
var num_generated_bulks : int = 0
var generated_bulks : Array
var inputs = []

var args_ports_by_name = {}
var num_in_ports : int = 0
var num_out_ports : int = 0
var num_ports : int = 0			 # Max of (in,out)
var meta_node: Dictionary = {}

var node_template : String
var show_disconnected_inputs : bool = false

var dirty : bool = false

# Filled during runtime
var deps : Array[ Dictionary ]			# Array of graphEdit connections where I'm the target
var dependants : Array[ Dictionary ]	# Array of graphEdit connections where I'm the source
var eval_id : int = 0
var err : String

# Render
var ui_scale : float = 1.0
var ui_position_offset := Vector2.ZERO 
var ui_node : FlowGraphNodeUI = null

var debug_row : int = -1
var flow_graph : FlowGraphResource = null
#var node_ui : FlowGraphNodeUI = null
# Populated by the factor
var template_name : String 

signal settings_changed( prop_name : StringName )
signal contents_changed

func exposeParam( name : String ) -> bool:
	return true

# Show the setting entries as 'disabled' when they are connected to other nodes
# controlling the values
func _validate_property(property: Dictionary) -> void:
	if is_input_connected( property.name ):
		property.usage |= PROPERTY_USAGE_READ_ONLY

func setupDrawDebug():
	#checkDrawDebug()
	#draw_debug.setupDraw()
	pass

func preExecute( ctx : FlowData.EvaluationContext ):
	eval_id = ctx.eval_id
	setError("")
	rng.seed = random_seed
	num_generated_bulks = 0
	num_connected_bulks = 0
	input_bulks = []
	generated_bulks = []
	
	deps.map(func( conn : Dictionary ):
		# The number of bulks in the pin 0 defines how many bulks we are going to generate
		if conn.to_port == 0:
			var node = ctx.graph.nodes_by_name.get( conn.from_node )
			if node:
				num_connected_bulks += node.num_generated_bulks
	)
	if num_connected_bulks == 0:
		num_connected_bulks = 1

func onPropChanged( prop_name : StringName ):
	dirty = true
	settings_changed.emit( prop_name )
	
func notifyChange():
	settings_changed.emit( StringName() )
	
func getCategory() -> String:
	var meta := getMeta()
	return meta.get( "category", "Others...")
	
func setError( new_err : String ):
	#if new_err:
		#push_error( "Node.Err %s : %s" % [ name, new_err ])
		#editor_state_changed.emit()
	#err = new_err
	#redrawUI()
	pass

func setExecTime(usec: int):
	set_meta("exec_time_usec", usec)
	#if is_inside_tree():
		#queue_redraw()
	pass

func getMeta() -> Dictionary:
	return meta_node
	
func getTitle() -> String:
	return title

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
		FlowData.DataType.Color:
			return TYPE_COLOR
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
		TYPE_COLOR:
			return FlowData.DataType.Color
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

func getExposedParams():
	var meta := getMeta()
	if meta.get( "hide_inputs", false ):
		return []
	var trace = meta.get( "trace", false )
	trace = true
	# transform.gd
	var settings_script_name = template_name + ".gd" #get_path().get_file()
	#print( "Starting exposed params for %s -> myscr:%s" % [ str(meta), my_script ])
	print( "settings_script_name:%s" % [ settings_script_name])
	
	var props := get_property_list()
	var inside_my_vars := false
	var params = []
	for prop : Dictionary in props:
		var pname : String = prop.name
		if trace:
			print( "Input. %s - %s Type:%d:%d:%s Usage:%d" % [ prop.name, prop.class_name, prop.type, prop.hint, prop.hint_string, prop.usage ] )
		if pname == "Common Settings":
			break
		if pname == "HiddenFromThisPoint":
			break
		if pname == settings_script_name:
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

func refreshConnectionFlags( editor : FlowGraphEditor ):	
	for arg_name in args_ports_by_name:
		args_ports_by_name[ arg_name ].connected = editor.is_node_port_connected( name, args_ports_by_name[ arg_name ].port )

	
# This returns the current value of the input configuration taking into account potencial connections and overrides of the inputs
func getSettingValue( ctx : FlowData.EvaluationContext, in_name : String, default_value = null):
	var meta = getMeta()
	var trace = meta.get( "trace", false ) or trace
	
	var value = get( in_name )
	if value == null:
		value = default_value
	if trace:
		print( "Searching the current value of input %s in %d inputs at node %s. ByName:%s vs %s.   Meta:%s" % [ in_name, inputs.size(), name, args_ports_by_name, inputs, meta ] )
	if args_ports_by_name.has( in_name ):
		var port = args_ports_by_name[ in_name ].port
		if trace:
			print( "Found at port %d.. Inputs has size %d" % [ port, inputs.size() ] )
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
						#print( "in_size is %d" % [ in_size ] )
						#print( "  stream is %s" % [ stream ] )
						var new_value = stream.container[0]
						if trace:
							print( "  -> Using %s = %s" % [ in_name, new_value ])
						if typeof( new_value ) != typeof( value ):
							push_warning( "  Type of %s (%d) does not match the expected type (%d)" % [ in_name, typeof(new_value), typeof(value) ])
						return new_value
	
	if trace:
		print( "Input %s using from settings %s" % [ in_name, str(value) ])
	return value

func newStream( size : int, new_name : String, init_value, data_type : FlowData.DataType ):
	var new_container = FlowData.Data.newContainerOfType( data_type )
	new_container.resize( size )
	if typeof(init_value) == TYPE_CALLABLE:
		var fn : Callable = init_value
		match data_type:
			FlowData.DataType.Bool:
				var typed_container : PackedByteArray = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.Int:
				var typed_container : PackedInt32Array = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.Float:
				var typed_container : PackedFloat32Array = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.Vector:
				var typed_container : PackedVector3Array = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.Color:
				var typed_container : PackedColorArray = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.String:
				var typed_container : PackedStringArray = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			FlowData.DataType.Resource:
				var typed_container : Array = new_container
				for idx in size:
					typed_container[idx] = fn.call(idx)
			_:
				push_error( "newStream(%d) type not supported" % [ data_type ])
				return null
	else:
		new_container.fill( init_value )
	return { 
		"data_type" : data_type,
		"container" : new_container,
		"name" : new_name
	}
	
func newFloatStream( size : int, new_name : String, init_value ):
	return newStream( size, new_name, init_value, FlowData.DataType.Float )

func getSceneRootNode3d( current : Node3D ) -> Node3D:
	while current and current.get_parent_node_3d():
		current = current.get_parent_node_3d()
	return current

# --------------------------------------------------------------------------
func set_output( port_idx : int, data : FlowData.Data ):
	if port_idx == 0:
		num_generated_bulks += 1
		generated_bulks.append( [] )
	var bulk : Array = generated_bulks[ num_generated_bulks - 1]
	if port_idx >= bulk.size():
		bulk.resize( port_idx + 1 )
	bulk[ port_idx ] = data
	if trace:
		if data:
			print( "%s Saving bulk %d, port %d with %s (%d entries)" % [ name, num_generated_bulks - 1, port_idx, data.streams.keys(), data.size() ] )
		else:
			print( "%s Saving bulk %d, port %d output is null" % [ name, num_generated_bulks - 1, port_idx ] )
	
func get_input( idx : int ):
	if idx >= inputs.size():
		push_error( "Input.%d does not exists in node %s. There are only %d" % [ idx, name, inputs.size() ])
		return []
	return inputs[ idx ]

func get_optional_input( idx : int ):
	if idx >= inputs.size():
		return null
	return inputs[ idx ]

func get_bulk_input( bulk_idx : int, port_idx : int ):
	if bulk_idx < input_bulks.size() && port_idx < getMeta().ins.size():
		return input_bulks[ bulk_idx ][ port_idx ]
	return null
	
func get_bulk_output( bulk_idx : int, port_idx : int ):
	if bulk_idx >= generated_bulks.size():
		push_error( "Node %s has not generated bulk %d" % [ name, bulk_idx ])
		return FlowData.Data.new()
	if port_idx >= generated_bulks[ bulk_idx ].size():
		push_error( "Node %s bulk %d has not generated output %d" % [ name, bulk_idx, port_idx ])
		return FlowData.Data.new()
	return generated_bulks[ bulk_idx ][ port_idx ]

func execute( ctx ):
	pass

func _getInputForBulkInContext( ctx : FlowData.EvaluationContext, bulk_idx : int, port_idx : int ):
	var bulk_counter = 0
	#print( "_getInputForBulkInContext( %d, %d )" % [ bulk_idx, port_idx ] )
	for conn in deps:
		var to_port = conn.to_port
		if to_port != port_idx:
			continue
		var src_node = ctx.graph.nodes_by_name.get( conn.from_node )
		if not src_node:
			continue
		#print( "  Found.src_node is %s. Has generated %d bulks. So far we have explored %d bulks" % [ src_node, src_node.generated_bulks.size(), bulk_counter ] )
		var from_port = conn.from_port
		for input_bulk_idx in range( src_node.generated_bulks.size() ):
			if bulk_counter == bulk_idx:
				return src_node.get_bulk_output( input_bulk_idx, from_port )
			bulk_counter += 1
	return null

func readAllInputsForBulk( ctx : FlowData.EvaluationContext, bulk_idx : int ):
	inputs = []
	var num_inputs : int = getMeta().ins.size()
	for port_idx in range( num_inputs ):
		var input =  _getInputForBulkInContext( ctx, bulk_idx, port_idx )
		if trace:
			print( "%s Input for bulk %d port %d is %s" % [ name, bulk_idx, port_idx, input ])
		inputs.append(input)
		
	# Read the options inputs, assuming they only generate a single bulk
	var option_idx = num_inputs
	for conn in deps:
		if conn.to_port >= num_inputs:
			#print( "Checking conn %s" % conn )
			var config_input = _getInputForBulkInContext( ctx, 0, conn.to_port )
			#print( "  -> %s" % config_input.streams  )
			if conn.to_port >= inputs.size():
				inputs.resize( conn.to_port + 1 )
			inputs[ conn.to_port ] = config_input
			option_idx += 1
	input_bulks.append( inputs )

# Defines the behaviour of the node in it's disabled status
# The default behaviour is to pass all inputs as outputs	
func executedDisabled( ctx : FlowData.EvaluationContext ):
	for bulk_index in range( num_connected_bulks ):
		readAllInputsForBulk( ctx, bulk_index )
		if inputs.size() > 0:
			set_output( 0, inputs[0] )

func getPreferredSpawnPath():
	return null

func onSceneChanged( ctx : FlowData.EvaluationContext ):
	
	# Just supporting nodes without inputs, that have flagged as scans_scene = true
	# basically looking for all scan_* nodes
	if num_connected_bulks != 1 or meta_node.ins.size() > 0 or not meta_node.get( "scans_scene", false):
		return
		
	# Check if we have something generated
	if generated_bulks.size() == 1 and generated_bulks[0].size() == 1:
		var last_output = get_bulk_output( 0, 0 )
		if last_output:
			# last_output.dump( "Last output" )
			# We need to run the preExecute otherwise a second evaluation will appear as a second bulk
			preExecute( ctx )
			execute( ctx )
			var current_output = get_bulk_output( 0, 0 )
			if current_output:
				#current_output.dump( "New output")
				
				# Do not become dirty if the output has not changed by doing a early exit
				if last_output.equals( current_output ):
					# print( "The regenerated data for %s is the same. So the node does not become dirty" % name )
					return;

	# if we reach this point, the node requires is dirty and all dependants will do. We have evaluated the
	# node twice but potentially saved a lot of nodes in the general case
	dirty = true

func run( ctx : FlowData.EvaluationContext ):
	for bulk_index in range( num_connected_bulks ):
		if trace:
			print( "%s Preparing inputs for bulk %d/%d" % [ name, bulk_index, num_connected_bulks ])
		readAllInputsForBulk( ctx, bulk_index )
		if trace:
			print( "%s Inputs for bulk %d/%d are %s (%d)" % [ name, bulk_index, num_connected_bulks, inputs, inputs.size() ])
		execute( ctx )

func removeRegisteredInstancedNodes( spawn_parent : Node3D ):
	if trace:
		print( "%s.removeRegisteredInstancedNodes( %s )" % [ name, spawn_parent.name ] )
	var nodes : Array[Node] = []
	if spawn_parent:
		for child in spawn_parent.get_children():
			if !child.has_meta( "flow_owner" ):
				continue
			if child.get_meta( "flow_owner" ) == name:
				nodes.append( child )
	for node in nodes:
		if trace:
			print( "  Removing %s" % [ node.name ] )
		node.name += "_removed"
		node.queue_free()

func registerInstancedNode( new_owner : Node3D, new_parent : Node3D, child : Node3D ):
	if trace:
		print( "%s.registerInstancedNode( Owner:%s, Parent:%s, Child:%s )" % [ name, new_owner.name, new_parent.name, child.name ] )
	new_parent.add_child( child )
	child.owner = new_owner
	child.set_meta("flow_owner", name )

func is_input_connected( what : StringName ) -> bool:
	return args_ports_by_name.has( what ) and args_ports_by_name.get( what ).connected
