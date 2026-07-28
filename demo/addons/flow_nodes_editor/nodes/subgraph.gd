@tool
extends FlowNodeBase
class_name FlowNodeSubGraph

@export var graph : FlowGraphResource :
	set(value):
		print( "New graph assigned!" )
		if _graph and _graph.in_params_changed.is_connected(_onGraphInputsChanged):
			_graph.in_params_changed.disconnect(_onGraphInputsChanged)
		_graph = value
		if _graph and not _graph.in_params_changed.is_connected(_onGraphInputsChanged):
			_graph.in_params_changed.connect(_onGraphInputsChanged)
		overrides = FlowGraphOverrides.syncWithGraph(_graph, overrides)
		setupFromGraph()
		notify_property_list_changed()
		emit_changed()
		connections_changed.emit()
	get():
		return _graph

@export var overrides: Array[FlowGraphParamOverride] = []

var _graph : FlowGraphResource = FlowGraphResource.new()
var loop_index := 0

func _init():
	meta_node = {
		"title" : "Subgraph",
		"category" : "Control Flow",
		"ins" : [],
		"outs" : [],
		"is_final" : true,
		"tooltip" : "Evaluates a nested graph inside this node",
		"widget" : preload( "res://addons/flow_nodes_editor/flow_graph_node_ui_subgraph.gd" ),
		"trace" : true,
		"hide_inputs" : true
	}
func getTitle() -> String:
	if graph:
		return graph.graph_name
	return "Subgraph"

func exposeParam(param_name: String) -> bool:
	return param_name != "overrides"

func exposedAsInputNode(prop) -> bool:
	return not String(prop.name).begins_with(FlowGraphOverrides.PROPERTY_PREFIX)

func _get_property_list() -> Array:
	return FlowGraphOverrides.getPropertyList(graph)

func _get(property: StringName):
	return FlowGraphOverrides.getProperty(graph, overrides, property)

func _set(property: StringName, value: Variant) -> bool:
	if not FlowGraphOverrides.setProperty(graph, overrides, property, value):
		return false
	var parts := String(property).split("/")
	var param_id := StringName(parts[1])
	invalidate()
	settings_changed.emit(param_id)
	return true

func initializeOverrides() -> void:
	overrides = FlowGraphOverrides.duplicateAll(overrides)
	overrides = FlowGraphOverrides.syncWithGraph(graph, overrides)

func _onGraphInputsChanged() -> void:
	refreshFromGraph()

func refreshFromGraph() -> void:
	overrides = FlowGraphOverrides.syncWithGraph(graph, overrides)
	setupFromGraph()
	notify_property_list_changed()
	invalidate()
	emit_changed()
	connections_changed.emit()

func setupFromGraph():
	var ins = []
	var outs = []
	if graph:
		
		var time_node_start := Time.get_ticks_usec()
		graph.compile()
		var time_node_end := Time.get_ticks_usec()
		
		for param in graph.in_params:
			if param:
				ins.append({
					"label": param.name,
					"data_type": param.getDataType()
				})
		if graph.data and graph.data.has("nodes"):
			for n_data in graph.data["nodes"]:
				if n_data.get("template") == "output":
					var settings = n_data.get( "settings", {})
					print( "Output node is: %s" % n_data )
					var out_name = settings.get("out_name", "Output" )
					var out_type = settings.get("data_type", FlowData.DataType.Invalid)
					if out_type == FlowData.DataType.Invalid:
						out_type = FlowData.DataType.Any
					outs.append({
						"label": out_name,
						"data_type": out_type, 
						"provider_node" : n_data.name
					})
					
	meta_node.ins = ins
	meta_node.outs = outs

	if meta_node.trace:
		print( "%s.subgraph refreshFromSettings ins=%d Graph=%s" % [ name, ins.size(), graph ])
		print( "Subgraph meta", meta_node )

	#super.refreshFromSettings()

func resetSubgraph( graph : FlowGraphResource ):
	print( "The graph is new!")
	var in_p := GraphInputParameter.new()
	in_p.is_constant = false
	in_p.name = "In"
	in_p.data_type = FlowData.DataType.Invalid
	in_p.ensureId()
	graph.data = {
		"type": "flow_graph_nodes",
		"version": 1,
		"min_pos" : "(80.0, 160.0)",
		"links" : [
			{ 
				"from_node" : "id_0001_input_In", "from_port" : 0,
				"to_node" : "id_0002_output", "to_port" : 0
			}
		],
		"nodes" : [{
			"name": "id_0001_input_In",
			"position": "(80.0, 80.0)",
			"template": "input_In",
			"settings": {
				"input_id": in_p.param_id,
				"input_name": "In",
			}
		}, 
		{
			"name": "id_0002_output",
			"position": "(400.0, 80.0)",
			"template": "output",
			"settings": {
				"out_name": "Out",
				"data_type": FlowData.DataType.Any,
			}
		}]
	}
	graph.in_params.append( in_p )
	FlowNodeIO.create_nodes_from_dict( graph.data, graph, Vector2(0,0))

# This ctx is the context evaluating the subgraph node, not the subgraph itself
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute( ctx )
	loop_index = 0
	ctx.clearChildContexts(self)
	if graph:
		if trace:
			print( "Subgraph.Ensuring graph is compiled" )
		var time_node_start := Time.get_ticks_usec()
		graph.compile()
		var time_node_end := Time.get_ticks_usec()
		if trace:
			print( "Subgraph.Readed resource in %s (%s)" % [ time_node_end - time_node_start, graph.resource_path ])
	else:
		print( "subgraph has no active graph" )
		
func execute( ctx : FlowData.EvaluationContext ):
	if not graph:
		setError(ctx, "No graph assigned to Subgraph node '%s'" % getTitle())
		return
	
	var ins = meta_node.ins
	#print( "Subgraph, required ins are ", ins)
		
	var outs = meta_node.outs
	#print( "Subgraph.outs ", outs )
	var subctx := ctx.getChildContext(self, loop_index, graph)
	var previous_subctx := ctx.findChildContext(self, loop_index - 1) if loop_index > 0 else null
	
	#print( graph.data )
	#print( "All nodes", all_nodes )
	#print( "Subgraph.Nodes to eval in order", nodes )
	subctx.inputs.clear()
	var input_idx : int = 0
	for input in ins:
		if trace:
			print( "  Checking subgraph input %s" % [ input.label ])
		var is_feedback := false
		# Feedback does not happen in the first bulk
		if loop_index > 0:
			for output in outs:
				if output.label == input.label:
					#print( "  Output and Input labels match!!")
					var node_output : FlowNodeBase = graph.nodes_by_name.get( output.provider_node )
					if node_output and previous_subctx:
						var last_output := previous_subctx.getInputAt(node_output, 0, 0)
						if last_output:
							#last_output.dump( "  Last output" )
							subctx.inputs[ input.label ] = last_output
							is_feedback = true
							break
						else:
							#print( "  No output yet, can't feedback yet...")
							pass
		if not is_feedback and _isInputPortConnected(input_idx):
			var input_nth = getOptionalInput(ctx, input_idx)
			if trace:
				print( "  Input[%d] %s is connected, value is %s" % [ input_idx, input.label, input_nth ])
				if input_nth:
					input_nth.dump( "    input of subgraph" )
				else:
					print( "    Input is null!!!")
			subctx.inputs[ input.label ] = input_nth
		elif not is_feedback:
			var override := FlowGraphOverrides.findEnabled(overrides, input.label)
			if override:
				if trace:
					print("  Input %s is using subgraph override %s" % [input.label, override.value])
				subctx.inputs[input.label] = override.getAsFlowData()
		input_idx += 1
		
	subctx.markAllNodesDirty()
		
	subctx.computeDirtyNodesAndRun()
	
	var output_idx : int = 0
	for output in outs:
		#print( "Subgraph.Output[%d] was %s" % [output_idx, output])
		var node_output = subctx.graph.nodes_by_name.get( output.provider_node )
		if node_output:
			for bulk_idx in subctx.getConnectedBulkCount(node_output):
				var result := subctx.getInputAt(node_output, bulk_idx, 0)
				if result:
					#result.dump( "Iter" )
					setOutput(ctx, output_idx, result)
				else:
					setOutput(ctx, output_idx, FlowData.Data.new())
					
		else:
			setOutput(ctx, output_idx, FlowData.Data.new())
		output_idx += 1
			
	FlowPlugin.get_instance().register_executor(ctx.owner, graph, loop_index, subctx)
	loop_index += 1

func _isInputPortConnected(port_idx: int) -> bool:
	for connection in deps:
		if connection.to_port == port_idx:
			return true
	return false
