@tool
extends Resource
class_name FlowGraphResource

# This the resource to store a full flow graph

@export_category("Flow Graph Resource")

# Where we store the graph_nodes + custom settings as a dict
@export var data: Dictionary = {}
@export var graph_name : String:
	set(value):
		graph_name = value
		emit_changed()
	get:
		if graph_name:
			return graph_name
		if resource_name != "":
			return resource_name
		if resource_path != "":
			return resource_path.get_file().get_basename()
		return "Flow Graph"

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

# The compilated version of the resource, which is shared between all the instances using this resource
var loading : bool = false:
	set(value):
		loading = value
		print( "Res %s.loading = %s  InSize:%d" % [ graph_name, value, in_params.size() ])
	get:
		return loading
var compiled : bool = false
		
var nodes_by_name : Dictionary
var all_connections : Array[ Dictionary ]
var all_frames : Array[ Dictionary ]
var all_nodes : Array[ FlowNodeBase ]
var input_nodes : Array[ FlowNodeBase ]

var editor : FlowGraphEditor

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
	
	print( "addNodeFromTemplate %s %s" % [ node_template, node_name ])
	var factory := FlowPlugin.get_instance().nodes_factory
	if node_name and nodes_by_name.has( node_name ):
		node_name = factory.getNewName(node_template)
		print( "will use new name %s" % [ node_name ])
	
	var node = factory.createNewNode( null, node_template, node_name, node_settings )
	if node:
		nodes_by_name[ node.name ] = node
		all_nodes.append( node )
		node.dirty = true
		node.runtime_only = editor == null
		node.flow_graph = self
		if not node.settings.title:
			node.settings.title = node.getTitle()
		
		if node and node.settings and node.settings is InputNodeSettings:
			input_nodes.append( node )
		
		if editor:
			editor.onNodeCreated(node)
		
		return node
	
func disconnect_nodes( from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var idx = all_connections.find_custom( func( c : Dictionary ) -> bool:
		return c.from_node == from_node and c.from_port == from_port and c.to_node == to_node and c.to_port == to_port
	)
	if idx >= 0:
		
		# Remove the cached connections
		var from_node_ptr = nodes_by_name.get( from_node )
		if from_node_ptr:
			_delete_connections_involving_node( from_node_ptr.dependants, to_node )
		var to_node_ptr = nodes_by_name.get( to_node )
		if to_node_ptr:
			_delete_connections_involving_node( to_node_ptr.deps, from_node )
			
		all_connections.remove_at( idx )
	
func connect_nodes( from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var conn = { "from_node": from_node, "from_port" : from_port, "to_node" : to_node, "to_port" : to_port }
	all_connections.append( conn )
	var src_node : FlowNodeBase = nodes_by_name.get(from_node)
	var dst_node : FlowNodeBase = nodes_by_name.get(to_node)
	if src_node and dst_node:
		src_node.dependants.append(conn)
		dst_node.deps.append(conn)
	else:
		print( "graph.conn FAILED From:%s:%d To:%s:%d" % [ from_node, from_port, to_node, to_port ])
		print( "nodes_by_name: %s" % [ nodes_by_name ])
		if not src_node:
			print( "  from_node is %s" % [ from_node ])
		if not dst_node:
			print( "  to_node is %s" % [ to_node ])
			
	if editor:
		editor.onConnCreated( conn )
		
func _delete_connections_involving_node( conns : Array[ Dictionary ], node_name : StringName ):
	for i in range(conns.size() - 1, -1, -1):
		var conn := conns[i]
		if conn.from_node == node_name or conn.to_node == node_name:
			conns.remove_at(i)
		
func delete_node( node : FlowNodeBase ):
	var node_name : StringName = node.name
	# remove connections to that node
	_delete_connections_involving_node( all_connections, node_name )
	
	for conn_dep in node.deps:
		var other_node = nodes_by_name.get( conn_dep.from_node )
		if other_node:
			_delete_connections_involving_node( other_node.dependants, node_name )
			
	for conn_dependant in node.dependants:
		var other_node = nodes_by_name.get( conn_dependant.to_node )
		if other_node:
			_delete_connections_involving_node( other_node.deps, node_name )
			
	nodes_by_name.erase( node_name )
	all_nodes.erase( node )
	input_nodes.erase( node )
	node.queue_free()

func delete_frame( frame_name ):
	var idx = all_frames.find_custom( func( c ) : return c.name == frame_name )
	print( "Deleteing frame %s returned idx %d" % [ frame_name, idx ])
	if idx >= 0:
		all_frames.remove_at( idx )
		
func addFrame( frame_data : Dictionary ):
	all_frames.append( frame_data )
	if editor:
		editor.onFrameCreated( frame_data )
		
func markAllNodesDirty():
	for node in all_nodes:
		node.dirty = true
	
func dump():
	print( ">>>> FlowGraph %s.. %s Compiled:%s" % [resource_name, graph_name, compiled] )
	print( "  %d Nodes" % all_nodes.size() )
	for node in all_nodes:
		print( "    %s" % node.name )
		for dep in node.deps:
			if dep.to_node != node.name:
				push_error( "In node %s. Inconsistency in dep %s" % [node.name, dep])
			print( "      DependsOn %s:%d to me:%d" % [dep.from_node, dep.from_port, dep.to_port])
		for dependant in node.dependants:
			if dependant.from_node != node.name:
				push_error( "In node %s. Inconsistency in dependant %s" % [node.name, dependant])
			print( "      Dependant me:%d to %s:%d" % [dependant.from_port, dependant.to_node, dependant.to_port])
	print( "  %d Input Nodes" % input_nodes.size() )
	for node in input_nodes:
		print( "    %s %s" % [ node.name, node.settings.name ])
	print( "  %d Connections" % all_connections.size() )
	for conn in all_connections:
		print( "    %s:%d <-> %s:%d" % [ conn.from_node, conn.from_port, conn.to_node, conn.to_port ])
	print( "  %d Frames" % all_frames.size() )
	for frame in all_frames:
		print( "    %s" % [ frame ])

func compile():
	if compiled:
		return
	print( "FlowGraph.Compilation.Starts (%s)" % [ resource_path ])
	all_connections.clear()
	all_nodes.clear()
	nodes_by_name.clear()
	input_nodes.clear()
	var time_node_start := Time.get_ticks_usec()
	if data and not data.is_empty():
		FlowNodeIO.create_nodes_from_dict( data, self, Vector2(0,0) )
	var time_node_end := Time.get_ticks_usec()
	print( "FlowGraph.Compilation.Ends in %s (%s)" % [ time_node_end - time_node_start, resource_path ])
	compiled = true
	dump()
