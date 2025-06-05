class_name FlowNodeBase
extends GraphNode

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

	#func _init(new_lat: float, new_lon:float):
		#lat = new_lat
		#lon = new_lon
	#func _to_string():
		#return "(%f,%f)" % [lat, lon]

var inputs = []
var outputs = []

var connectors_row_prefab = preload( "res://connectors_row.tscn" )

func _ready():
	refreshInspectMark()
	refreshDebugMark()
	pass

func set_output( idx : int, data : Array ):
	if idx + 1 < outputs.size():
		outputs.resize( idx + 1 )
	outputs[ idx ] = data

func refreshDebugMark():
	if control_debug:
		control_debug.visible = debug_enabled

func refreshInspectMark():
	if control_inspect:
		control_inspect.visible = inspect_enabled

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
		
