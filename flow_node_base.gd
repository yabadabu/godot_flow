class_name FlowNodeBase
extends GraphNode

# Debug section
enum eMode {
	EXTENDS,
	ABSOLUTE,
}
@export var debug_enabled : bool = false :
	set(new_value):
		debug_enabled = new_value
		refreshDebugMark()

@export var inspect_enabled : bool = false :
	set(new_value):
		inspect_enabled = new_value
		refreshInspectMark()
		
@export var debug_mode : eMode = eMode.EXTENDS
@export var debug_scale : float = 1.0

@onready var control_inspect = %InspectMark
@onready var control_debug = %DebugMark

# Common attributes
var inputs = []
var outputs = []

@export var rng_seed : int = 8212421413;
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

# Helper to create the UI
var connectors_row_prefab = preload( "res://connectors_row.tscn" )

# Filled during runtime
var deps : Array[ Dictionary ]
var frame_id : int = 0

func _ready():
	refreshInspectMark()
	refreshDebugMark()
	
func isFinal() -> bool:
	return false

func set_output( idx : int, data : Array ):
	if idx >= outputs.size():
		outputs.resize( idx + 1 )
	outputs[ idx ] = data

func set_input( idx : int, data : Array ):
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
	rng.seed = rng_seed

func refreshDebugMark():
	if control_debug:
		control_debug.visible = debug_enabled

func refreshInspectMark():
	if control_inspect:
		control_inspect.visible = inspect_enabled

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
			set_slot_enabled_left( idx + 1, true )
		else:
			lbl_in.text = ""
			
		if idx < num_outs:
			lbl_out.text = outs[ idx ].label
			set_slot_enabled_right( idx + 1, true )
		else:
			lbl_out.text = ""
		
