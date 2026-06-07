@tool
extends FlowNodeBase

#var _connected_graph: FlowGraphResource = null
var subctx := FlowData.EvaluationContext.new()
var all_nodes : Array[ FlowNodeBase ]
var out_nodes : Dictionary

func _init():
	meta_node = {
		"title" : "Subgraph",
		"settings" : SubgraphNodeSettings,
		"ins" : [],
		"outs" : [],
		"is_final" : true,
		"tooltip" : "Evaluates a nested graph inside this node",
	}

func getTitle() -> String:
	if settings and settings.graph:
		var path = settings.graph.resource_path
		if path != "":
			return "Subgraph: %s" % path.get_file().get_basename()
		return "Subgraph (New Graph)"
	return "Subgraph"

func getMeta() -> Dictionary:
	var ins = []
	var outs = []
	if settings and settings.graph:
		for param in settings.graph.in_params:
			if param:
				ins.append({
					"label": param.name,
					"data_type": param.getDataType()
				})
		#if "out_params" in settings.graph and settings.graph.out_params.size() > 0:
			#for param in settings.graph.out_params:
				#if param:
					#outs.append({
						#"label": param.name,
						#"data_type": param.data_type
					#})
		if settings.graph.data and settings.graph.data.has("nodes"):
			for n_data in settings.graph.data["nodes"]:
				if n_data.get("template") == "output":
					var node_settings = n_data.get("settings", {})
					var out_name = node_settings.get("name", "out_val")
					var out_type = node_settings.get("data_type", FlowData.DataType.Float)
					outs.append({
						"label": out_name,
						"data_type": out_type, 
						"provider_node" : n_data.name
					})
	meta_node.ins = ins
	meta_node.outs = outs
	return meta_node
	
func addNodeFromTemplate( node_template, node_name : String, node_settings = null ):
	if settings.trace:
		print( "subgraph parsing ", node_template, " InName:", node_name)
	var editor = getEditor()
	if editor:
		var node = editor.nodes_factory.createNewNode( null, node_template, node_name, node_settings )
		if settings.trace:
			print( "  Registering ", node.name, " -> ", node)
		subctx.gedit_nodes_by_name[ node.name ] = node
		all_nodes.append( node )
		node.dirty = true
		#add_child(node)
		return node
	return null
	
func connect_nodes( from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node : FlowNodeBase = subctx.gedit_nodes_by_name.get(from_node)
	var dst_node : FlowNodeBase = subctx.gedit_nodes_by_name.get(to_node)
	if src_node and dst_node:
		var conn = { "from_node" : src_node.name, "from_port" : from_port, "to_node" : dst_node.name, "to_port" : to_port }
		src_node.dependants.append(conn)
		dst_node.deps.append(conn)
		#dst_node.args_ports_by_name[ ]
		#print( "subgraph.conn.ok From:%s:%d To:%s:%d (%s)" % [ from_node, from_port, to_node, to_port, conn ])
	else:
		print( "subgraph.conn FAILED From:%s:%d To:%s:%d" % [ from_node, from_port, to_node, to_port ])
		print( "subctx.gedit_nodes_by_name: %s" % [ subctx.gedit_nodes_by_name ])
		if not src_node:
			print( "  from_node is %s" % [ from_node ])
		if not dst_node:
			print( "  to_node is %s" % [ to_node ])
		
func addFrame( frame_data : Dictionary, old_to_new_names : Dictionary, paste_offset  ):
	pass
	
# This ctx is the context evaluating the subgraph node, not the subgraph itself
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute( ctx )
	
	all_nodes.clear()
	subctx.gedit_nodes_by_name.clear()
	print( "Subgraph.Reading resource")
	FlowNodeIO.create_nodes_from_dict( settings.graph.data, self, Vector2(0,0) )
	
	# I will need my own factory so the my inputs do not bother the inputs from other graphs 
	var editor = getEditor()
	for input in settings.graph.in_params:
		editor.registerInputNodeType( input )
		
	subctx.owner = ctx.owner
	subctx.graph = settings.graph
	subctx.trace = settings.trace
	
	#print( "subctx.gedit_nodes_by_name", subctx.gedit_nodes_by_name )
	var nodes = subctx.getEvalOrder( all_nodes )
	subctx.nodes_to_eval = nodes
	
	
func execute( ctx : FlowData.EvaluationContext ):
	if not settings.graph:
		setError("No graph assigned to Subgraph node '%s'" % getTitle())
		return
	
	var ins = meta_node.ins
	#print( "Subgraph, required ins are ", ins)
		
	var outs = meta_node.outs
	#print( "Subgraph.outs ", outs )
	
	#print( settings.graph.data )
	#print( "All nodes", all_nodes )
	for node in all_nodes:
		node.dirty = true
	
	#print( "Subgraph.Nodes to eval in order", nodes )
	var input_idx : int = 0
	for input in ins:
		#print( "Checking subgraph input %s" % [ input.label ])
		var is_feedback := false
		for output in outs:
			if output.label == input.label:
				#print( "  Output and Input labels match!!")
				var node_output : FlowNodeBase = subctx.gedit_nodes_by_name.get( output.provider_node )
				if node_output:
					#print( "  Found node_output: %d" % [node_output.num_connected_bulks])
					var last_output = node_output.get_bulk_input(0, 0)
					if last_output:
						#last_output.dump( "  Last output" )
						subctx.inputs[ input.label ] = last_output
						is_feedback = true
						break
					else:
						#print( "  No output yet, can't feedback yet...")
						pass
		if not is_feedback:
			subctx.inputs[ input.label ] = get_input(input_idx)
		input_idx += 1
		
		# Invalidate the input nodes as they have new values
		#var in_node = subctx.gedit_nodes_by_name.get( input.label )
		#if in_node:
			#in_node.dirty = true
		
	for node in all_nodes:
		node.dirty = true
		
	subctx.run()
	
	var output_idx : int = 0
	for output in outs:
		#print( "Subgraph.Output[%d] was %s" % [output_idx, output])
		var node_output = subctx.gedit_nodes_by_name.get( output.provider_node )
		if node_output:
			#print( " found the provider node %s NumBulks:%d " % [node_output.name, node_output.num_connected_bulks] )
			for bulk_idx in node_output.num_connected_bulks:
				var result = node_output.get_bulk_input(bulk_idx, 0)
				if result:
					#result.dump( "Iter" )
					set_output(output_idx, result)
				else:
					set_output(output_idx, FlowData.Data.new())
					
		else:
			set_output(output_idx, FlowData.Data.new())
		output_idx += 1
			
			
