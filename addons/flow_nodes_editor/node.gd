@tool
class_name FlowNodeBase
extends GraphNode

@export var settings: NodeSettings
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Common attributes
var inputs = []
var outputs = []

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
	
	var dpi = DisplayServer.screen_get_dpi()
	print( "Dpi is %d and %d" % [ DisplayServer.screen_get_dpi(), DisplayServer.screen_get_scale()])
	if dpi > 150:
		ui_scale *= 2.0
	
func _exit_tree():
	cleanup_multimesh_direct()
	
func cleanup_multimesh_direct():
	if instance_rid.is_valid():
		RenderingServer.free_rid(instance_rid)
		instance_rid = RID()

	if multimesh_rid.is_valid():
		RenderingServer.free_rid(multimesh_rid)
		multimesh_rid = RID()	
	
func isFinal() -> bool:
	return false

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

func getTitle() -> String:
	return settings.title

func shuffleArray(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func initFromScript():
	var meta = call("getMeta")
	
	var ins = meta.get( "ins", [] )
	var outs = meta.get( "outs", [] )
	var num_ins = ins.size()
	var num_outs = outs.size()
	var num_rows = max( num_ins, num_outs )
	
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
			lbl_out.text = outs[ idx ].label
			set_slot_enabled_right( idx, true )
		else:
			lbl_out.text = ""

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
		RenderingServer.multimesh_allocate_data(multimesh_rid, instance_count, RenderingServer.MultimeshTransformFormat.MULTIMESH_TRANSFORM_3D )
	
	for idx in range( instance_count ):
		var t := transforms.atIndex( idx )
		RenderingServer.multimesh_instance_set_transform( multimesh_rid, idx, t)
