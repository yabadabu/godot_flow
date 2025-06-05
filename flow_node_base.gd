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
