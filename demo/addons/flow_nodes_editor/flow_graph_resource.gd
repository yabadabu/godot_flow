@tool
extends Resource
class_name FlowGraphResource

# This the resource to store a full flow graph

@export_category("Flow Graph Resource")

# Where we store the graph_nodes + custom settings as a dict
@export var data: Dictionary = {}

# Visualization params
@export var view_zoom : float = 1.0
@export var view_offset : Vector2 = Vector2(0,0)

# To always generate unique name ids for each node
@export var new_name_counter : int = 0

@export var in_params : Array[GraphInputParameter] = []:
	set(value):
		in_params = value
		_watch_input_changes()
		emit_signal("in_params_changed")
	get:
		return in_params

signal in_params_changed

func _watch_input_changes():
	# Disconnect existing connections
	for param in in_params:
		if param is Resource and param.changed.is_connected(_on_input_changed):
			param.changed.disconnect(_on_input_changed)

	# Connect to current items
	for param in in_params:
		if param is Resource:
			param.changed.connect(_on_input_changed, CONNECT_DEFERRED)

func _on_input_changed():
	print("One of the in_params was modified.")
	emit_signal("in_params_changed")

func findInParamByName( requested_name : String ):
	for candidate in in_params:
		if candidate and candidate.name == requested_name:
			return candidate
	return null
