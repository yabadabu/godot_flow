@tool
class_name FlowNodeBase
extends GraphNode

@export var settings: NodeSettings
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Common attributes
var inputs = []
var outputs = []

var meta_node: Dictionary = {}

var node_template : String

# Helper to create the UI
var connectors_row_prefab = preload( "res://addons/flow_nodes_editor/connectors_row.tscn" )

# Filled during runtime
var deps : Array[ Dictionary ]
var eval_id : int = 0
var err : String

var scenario_rid : RID
var multimesh_rid : RID
var instance_rid : RID
var mesh_resource: Mesh = preload( "res://addons/flow_nodes_editor/resources/unit_cube.tres" )
var ui_scale = 1.0
var marker_radius : float = 9

func _ready():
	refreshInspectMark()
	refreshDebugMark()
	
	var viewport = get_viewport()
	if viewport:
		scenario_rid = viewport.get_world_3d().scenario
	else:
		print( "Viewport is invalid")
	
func _exit_tree():
	cleanup_multimesh_direct()
	
func cleanup_multimesh_direct():
	if instance_rid.is_valid():
		RenderingServer.free_rid(instance_rid)
		instance_rid = RID()

	if multimesh_rid.is_valid():
		RenderingServer.free_rid(multimesh_rid)
		multimesh_rid = RID()	

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

func get_output( idx : int ):
	if idx >= outputs.size():
		push_error( "Output.%d does not exists in node %s" % [ idx, name ])
		return []
	return outputs[ idx ]

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
	
func refreshFromSettings():
	refreshDebugMark()
	refreshInspectMark()
	title = getTitle()
	
	if not settings.debug_enabled:
		cleanup_multimesh_direct()
	
func create_multimesh_direct():
	if not mesh_resource:
		print("No mesh resource assigned")
		return
	
	cleanup_multimesh_direct()  # Clean up any existing
	
	# Create MultiMesh resource
	multimesh_rid = RenderingServer.multimesh_create()
	
	# Setup MultiMesh
	RenderingServer.multimesh_set_mesh(multimesh_rid, mesh_resource.get_rid())
	#RenderingServer.multimesh_allocate_data(multimesh_rid, instance_count, RS.MULTIMESH_TRANSFORM_3D)
	
	# Create instance transforms
	#setup_instance_transforms()
	
	# Create rendering instance
	instance_rid = RenderingServer.instance_create()
	RenderingServer.instance_set_base(instance_rid, multimesh_rid)
	
	# Add to current scenario (viewport world)
	if scenario_rid.is_valid():
		RenderingServer.instance_set_scenario(instance_rid, scenario_rid)
	
	# Set transform
	var global_transform : Transform3D = Transform3D.IDENTITY
	RenderingServer.instance_set_transform(instance_rid, global_transform)

func setError( new_err : String ):
	if new_err:
		push_error( "Node.Err %s : %s" % [ name, new_err ])
		editor_state_changed.emit()
	err = new_err
	redrawUI()
		
func _on_draw() -> void:

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

func getColorForGDScriptType( gd_type : int ) -> Color:
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
	return Color.WHEAT

func getGdScriptTypeForFlowDataType( data_type : FlowData.DataType ) -> int:
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

func getFlowDataTypeFromGdScriptType( gd_type : int  ) -> FlowData.DataType:
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

func initFromScript():
	var meta := getMeta()
	var trace = meta.get( "trace", false )
	
	var ins = meta.get( "ins", [] )
	var outs = meta.get( "outs", [] )
	var num_ins = ins.size()
	var num_outs = outs.size()
	var num_rows = max( num_ins, num_outs )
	var num_inputs = num_ins
	
	for idx in range( 0, num_rows ):
		var ctrl = connectors_row_prefab.instantiate()
		add_child( ctrl )
		var lbl_in = ctrl.get_child(0) as Label
		var lbl_out = ctrl.get_child(2) as Label
		if idx < num_ins:
			lbl_in.text = ins[ idx ].label
			set_slot_enabled_left( idx, true )
		else:
			lbl_in.text = ""
			
		if idx < num_outs:
			var out = outs[idx]
			lbl_out.text = out.label
			set_slot_enabled_right( idx, true )
			if out.has( "type"):
				var color = getColorForGDScriptType( out.type )
				set_slot_color_right( idx, color )
		else:
			lbl_out.text = ""
			
	if !meta.get( "hide_inputs", false ):
		var my_title : String = meta.title
		if !meta.has( "input_slots" ):
			meta.input_slots = {}
			if trace:
				print( "%s : Created empty input_slots %s" % [ name, my_title ] )
		var inputs = settings.get_property_list()
		var slot_idx = num_rows
		var inside_my_vars := false
		for input in inputs:
			if trace:
				print( "Input.", input.name)
			if input.name == "node_settings.gd":
				break
			if input.name == "HiddenFromThisPoint":
				break
			if input.name == my_title:
				inside_my_vars = true
			if !(input.usage & PROPERTY_USAGE_STORAGE) || !(input.usage & PROPERTY_USAGE_EDITOR):
				continue
			if !inside_my_vars:
				continue
			if trace:
				print( "%s : Input is %s" % [ name, input ] )
			var ictrl = connectors_row_prefab.instantiate()
			add_child( ictrl )
			var lbl_in = ictrl.get_child(0) as Label
			var lbl_out = ictrl.get_child(2) as Label
			set_slot_enabled_left( slot_idx, true )
			var color = getColorForGDScriptType( input.type )
			set_slot_color_left( slot_idx, color )
			lbl_in.text = editorDisplayName( input.name )
			lbl_out.text = ""
			slot_idx += 1
			
			meta.input_slots[ input.name ] = num_inputs
			if trace:
				print( "%s : Assigning slot %d for input %s when %d" % [ name, meta.input_slots[ input.name ], input.name, num_inputs ])
			num_inputs += 1

func setupDebugDraw():
	var out_data : FlowData.Data = get_output(0)
	if not out_data || !out_data.hasStream( FlowData.AttrPosition ):
		print( "setupDebugDraw failed - out_data" )
		return
		
	create_multimesh_direct()
		
	if not multimesh_rid.is_valid():
		print( "setupDebugDraw failed - multimesh_rid" )
		return
		
	var transforms := out_data.getTransformsStream()
	if transforms == null:
		print( "setupDebugDraw failed - positions/eulers" )
		return
	
	var instance_count = out_data.size()
	var current_count = RenderingServer.multimesh_get_instance_count(multimesh_rid)
	if instance_count != current_count:
		RenderingServer.multimesh_allocate_data(multimesh_rid, instance_count, RenderingServer.MultimeshTransformFormat.MULTIMESH_TRANSFORM_3D, true )
	
	if settings.debug_mode == NodeSettings.eDebugMode.EXTENDS:
		for idx in range( instance_count ):
			var t := transforms.atIndex( idx )
			RenderingServer.multimesh_instance_set_transform( multimesh_rid, idx, t)
			
	elif settings.debug_mode == NodeSettings.eDebugMode.ABSOLUTE:
		var abs_scale := settings.debug_scale
		for idx in range( instance_count ):
			var t := transforms.atIndexAbsScale( idx, abs_scale )
			RenderingServer.multimesh_instance_set_transform( multimesh_rid, idx, t)
		
	setupColors( out_data )

func setupColors( out_data : FlowData.Data ):
	var instance_count = out_data.size()
	var color : Color = settings.debug_color
	if settings.debug_modulate_by:
		var smod : PackedFloat32Array = out_data.getContainerChecked( settings.debug_modulate_by, FlowData.DataType.Float )
		if not smod:
			setError( "Attribute %s of type Float not found" % settings.debug_modulate_by )
		else:
			for idx in range( instance_count ):
				RenderingServer.multimesh_instance_set_color( multimesh_rid, idx, color * smod[idx] )
			return
	for idx in range( instance_count ):
		RenderingServer.multimesh_instance_set_color( multimesh_rid, idx, color )
	
	
# This returns the current value of the input configuration taking into account potencial connections and overrides of the inputs
func getSettingValue( ctx : FlowData.EvaluationContext, in_name : String ):
	var meta = getMeta()
	var inputs_by_name = meta.get( "input_slots", {})
	var trace = meta.get( "trace", false )
	if trace:
		print( "Searching the current value of input %s in %d inputs at node %s. ByName:%s vs %s.   Meta:%s" % [ in_name, inputs.size(), name, inputs_by_name, inputs, meta ] )
	var idx = inputs_by_name.get( in_name, -1 )
	if idx != -1 and idx < inputs.size():
		#print( "  Meta input %s is at slot %d " % [ in_name, idx ] )
		var input = inputs[ idx ] as FlowData.Data
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
					var value = stream.container[0]
					if trace:
						print( "  -> Using %s = %s" % [ in_name, value ])
					return value
			
	return settings.get( in_name )

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
