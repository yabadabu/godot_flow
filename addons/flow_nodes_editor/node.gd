@tool
class_name FlowNodeBase
extends GraphNode

@export var settings: NodeSettings
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Common attributes
var inputs = []
var outputs = []

# Helper to create the UI
var connectors_row_prefab = preload( "res://addons/flow_nodes_editor/connectors_row.tscn" )

# Filled during runtime
var deps : Array[ Dictionary ]
var frame_id : int = 0
var err : String

func _ready():
	refreshInspectMark()
	refreshDebugMark()
	
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

func preExecute():
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
	title = settings.title
	
func setError( new_err : String ):
	push_error( "Node.Err %s : %s" % [ name, new_err ])
	err = new_err
	editor_state_changed.emit()
		
func _on_draw() -> void:
		
	if err:
		self_modulate = Color(1.0, 0.5, 0.5)
		draw_string( ThemeDB.fallback_font, Vector2(0,size.y + 32), err, HORIZONTAL_ALIGNMENT_LEFT, -1, 32 )
	else:
		self_modulate = Color.WHITE
		
	if settings.inspect_enabled:
		var clr : Color = Color.YELLOW / self_modulate
		draw_circle( Vector2(0,0), 16.0, clr )
	if settings.debug_enabled:
		var clr : Color = Color.CYAN / self_modulate
		draw_circle( Vector2(size.x,0), 16.0, clr )

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
