@tool
extends FlowNodeBase

var subctx := FlowData.EvaluationContext.new()
var loop_index := 0

func _init():
	meta_node = {
		"title" : "Subgraph",
		"settings" : SubgraphNodeSettings,
		"category" : "Control Flow",
		"ins" : [],
		"outs" : [],
		"is_final" : true,
		"tooltip" : "Evaluates a nested graph inside this node"
	}

func _ready():
	super._ready()
	subctx.name = name + "_ctx"

func getTitle() -> String:
	if settings and settings.graph:
		return settings.graph.graph_name
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
		if editor and settings:
			if not settings.graph:
				settings.graph = FlowGraphResource.new()
			var graph : FlowGraphResource = settings.graph
			var owner = editor.resource_owner
			print( "settings.graph.data", graph.data)
			print( "settings.graph.resource_name", graph.resource_name )
			print( "settings.graph.resource_path", graph.resource_path )
			
			if not graph.data:
				print( "The graph is new!")
				graph.data = {
					"type": "flow_graph_nodes",
					"version": 1,
					"min_pos" : "(80.0, 160.0)",
					"links" : [],
					"nodes" : [{
						"name": "id_0001_input_In",
						"position": "(80.0, 80.0)",
						"template": "input_In",
						"settings": { "name": "In", }
					}, 
					{
						"name": "id_0002_output",
						"position": "(400.0, 80.0)",
						"template": "output",
						"settings": { "name": "Out", }
					}]
				}
				var in_p = GraphInputParameter.new()
				in_p.is_constant = false
				in_p.name = "In"
				in_p.data_type = FlowData.DataType.Invalid
				graph.in_params.append( in_p )
				FlowNodeIO.create_nodes_from_dict( graph.data, graph, Vector2(0,0))
				
			editor.setResourceToEdit(settings.graph, owner)
			
			accept_event()	
	
# This ctx is the context evaluating the subgraph node, not the subgraph itself
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute( ctx )
	loop_index = 0
	if settings.graph:
		if settings.trace:
			print( "Subgraph.Ensuring graph is compiled" )
		var time_node_start := Time.get_ticks_usec()
		settings.graph.compile()
		var time_node_end := Time.get_ticks_usec()
		if settings.trace:
			print( "Subgraph.Readed resource in %s (%s)" % [ time_node_end - time_node_start, settings.graph.resource_path ])
				
		subctx.owner = ctx.owner
		subctx.graph = settings.graph
		subctx.trace = settings.trace
		subctx.parent_ctx = ctx
		subctx.name = "exec_%s" % name
		subctx.nodes_to_eval = subctx.getEvalOrder( subctx.graph.all_nodes )
	else:
		print( "subgraph has no active graph" )
		
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
		if settings.trace:
			print( "  Checking subgraph input %s" % [ input.label ])
		var is_feedback := false
		# Feedback does not happen in the first bulk
		if loop_index > 0:
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
			var input_nth = get_input(input_idx)
			if settings.trace:
				print( "  Input[%d] %s is not feedback, value is %s" % [ input_idx, input.label, input_nth ])
				if input_nth:
					input_nth.dump( "    input of subgraph" )
				else:
					print( "    Input is null!!!")
			subctx.inputs[ input.label ] = input_nth
		input_idx += 1
		
	settings.graph.markAllNodesDirty()
		
	subctx.computeDirtyNodesAndRun()
	
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
			
	FlowPlugin.get_instance().register_executor( ctx.owner, settings.graph, loop_index )
	loop_index += 1
