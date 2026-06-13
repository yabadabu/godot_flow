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
		validateAndWatchNewInputs()
	get:
		return in_params

# The compilation version of the resource, which is shared between all the instances using this resource
var compiled : bool = false
var nodes_by_name : Dictionary
var all_nodes : Array[ FlowNodeBase ]
var input_nodes : Array[ FlowNodeBase ]

signal in_params_changed

func validateAndWatchNewInputs():
	for idx in range(in_params.size()):
		if in_params[idx] == null:
			var param := GraphInputParameter.new()
			param.name = "input_%d" % idx
			in_params[idx] = param
	_watch_input_changes()
	in_params_changed.emit()	

func _watch_input_changes():
	print("Flow Graph._watch_input_changes")
	# Disconnect existing connections
	for param in in_params:
		if param is Resource and param.changed.is_connected(_on_input_changed):
			param.changed.disconnect(_on_input_changed)

	# Connect to current items
	for param in in_params:
		if param is Resource:
			param.changed.connect(_on_input_changed, CONNECT_DEFERRED)

func _on_input_changed():
	print("Flow Graph.One of the in_params was modified.")
	in_params_changed.emit()

func findInParamByName( requested_name : String ) -> GraphInputParameter:
	for candidate in in_params:
		if candidate and candidate.name == requested_name:
			return candidate
	return null
	
# Compile callbacks
func addNodeFromTemplate( node_template, node_name : String, node_settings = null ):
	var node = FlowPlugin.get_instance().nodes_factory.createNewNode( null, node_template, node_name, node_settings )
	if node:
		nodes_by_name[ node.name ] = node
		all_nodes.append( node )
		node.dirty = true
		node.runtime_only = true
		#add_child(node)
		
		if node and node.settings and node.settings is InputNodeSettings:
			input_nodes.append( node )
		
		return node
	
func connect_nodes( from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node : FlowNodeBase = nodes_by_name.get(from_node)
	var dst_node : FlowNodeBase = nodes_by_name.get(to_node)
	if src_node and dst_node:
		var conn = { "from_node" : src_node.name, "from_port" : from_port, "to_node" : dst_node.name, "to_port" : to_port }
		src_node.dependants.append(conn)
		dst_node.deps.append(conn)
	else:
		print( "subgraph.conn FAILED From:%s:%d To:%s:%d" % [ from_node, from_port, to_node, to_port ])
		print( "subctx.nodes_by_name: %s" % [ nodes_by_name ])
		if not src_node:
			print( "  from_node is %s" % [ from_node ])
		if not dst_node:
			print( "  to_node is %s" % [ to_node ])
		
func addFrame( frame_data : Dictionary, old_to_new_names : Dictionary, paste_offset  ):
	# frames are not parsed
	pass	
	
func compile():
	all_nodes.clear()
	nodes_by_name.clear()
	input_nodes.clear()
	var time_node_start := Time.get_ticks_usec()
	FlowNodeIO.create_nodes_from_dict( data, self, Vector2(0,0) )
	var time_node_end := Time.get_ticks_usec()
	print( "FlowGraph.Compiled in %s (%s)" % [ time_node_end - time_node_start, resource_path ])
	for node in input_nodes:
		print( "  Input: %s %s" % [ node.name, node.settings.name ])
	compiled = true
