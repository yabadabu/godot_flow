class_name FlowNodeBase
extends GraphNode

enum eMode {
	EXTENDS,
	ABSOLUTE,
}
@export var debug_enabled : bool = false
@export var debug_mode : eMode = eMode.EXTENDS
@export var debug_scale : float = 1.0

	#func _init(new_lat: float, new_lon:float):
		#lat = new_lat
		#lon = new_lon
	#func _to_string():
		#return "(%f,%f)" % [lat, lon]

var inputs = []
var outputs = []

func set_output( idx : int, data : Array ):
	if idx + 1 < outputs.size():
		outputs.resize( idx + 1 )
	outputs[ idx ] = data

#func get_input( idx : int ):
	#if idx + 1 < inputs.size():
		#return null
	#return inputs[ idx ]
