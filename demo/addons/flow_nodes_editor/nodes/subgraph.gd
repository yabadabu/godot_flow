@tool
extends FlowNodeBase

#var _connected_graph: FlowGraphResource = null
var subctx := FlowData.EvaluationContext.new()

func _init():
	meta_node = {
		"title" : "Subgraph",
		"settings" : SubgraphNodeSettings,
		"category" : "Control Flow",
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

# Double click to trigger openning the subgraph
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		var editor = getEditor()
		if editor and settings and settings.graph:
			var owner = editor.resource_owner
			editor.setResourceToEdit(settings.graph, owner)
			accept_event()	
	
# This ctx is the context evaluating the subgraph node, not the subgraph itself
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute( ctx )
	if settings.graph:
		var time_node_start := Time.get_ticks_usec()
		FlowNodeIO.create_nodes_from_dict( settings.graph.data, settings.graph, Vector2(0,0) )
		var time_node_end := Time.get_ticks_usec()
		print( "Subgraph.Readed resource in %s (%s)" % [ time_node_end - time_node_start, settings.graph.resource_path ])
				
		subctx.owner = ctx.owner
		subctx.graph = settings.graph
		subctx.trace = settings.trace
		subctx.parent_ctx = ctx
		subctx.name = "exec_%s" % name
		subctx.nodes_to_eval = subctx.getEvalOrder( subctx.graph.all_nodes )

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
	for node in settings.graph.all_nodes:
		node.dirty = true
	
	#print( "Subgraph.Nodes to eval in order", nodes )
	subctx.inputs.clear()
	var input_idx : int = 0
	for input in ins:
		#print( "Checking subgraph input %s" % [ input.label ])
		var is_feedback := false
		for output in outs:
			if output.label == input.label:
				#print( "  Output and Input labels match!!")
				var node_output : FlowNodeBase = settings.graph.nodes_by_name.get( output.provider_node )
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
		
	for node in settings.graph.all_nodes:
		node.dirty = true
		
	subctx.run()
	
	var output_idx : int = 0
	for output in outs:
		#print( "Subgraph.Output[%d] was %s" % [output_idx, output])
		var node_output = subctx.graph.nodes_by_name.get( output.provider_node )
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
			
			
