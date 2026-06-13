@tool
extends Node3D
class_name FlowGraphNode3D

# This is the Node3d the user will instantiate in his final 3D scenes to trigger
# the generation of pcg
# It technically should not need to be a Node3D, as the transform is not really used
# but I'm currently generating the spawned nodes as child of this nodes

@export var graph : FlowGraphResource :
	set(new_value):
		if _graph and _graph.in_params_changed.is_connected(_on_graph_inputs_change):
			_graph.in_params_changed.disconnect(_on_graph_inputs_change)
		_graph = new_value
		if _graph:
			_graph.in_params_changed.connect(_on_graph_inputs_change)
		graph_node_changed.emit( self, "graph_resource" )
	get:
		return _graph
		
var _graph : FlowGraphResource = FlowGraphResource.new()
signal graph_node_changed( graph_node : FlowGraphNode3D, prop_name : String )

@export var overrides: Array[FlowGraphParamOverride] = []

func _on_graph_inputs_change():
	print( "_on_graph_inputs_change" )
	var existing := {}
	for o in overrides:
		existing[o.param_id] = o
	var new_overrides : Array[FlowGraphParamOverride] = []
	for input in graph.in_params:
		if existing.has(input.name):
			new_overrides.append(existing[input.name])
		else:
			var o := FlowGraphParamOverride.new()
			o.param_id = input.name
			o.value = input.getDefaultValue()
			o.enabled = false
			new_overrides.append(o)
	overrides = new_overrides

# You can also use get_property_list() for more control
func _get_property_listx():
	return [
		{
			"name": "refresh_inputs",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON | PROPERTY_USAGE_EDITOR,
			"hint_string": "Refresh Inputs"
		}
	]

func _get_property_list() -> Array:
	var props := []

	if graph == null:
		print( "At FlowGraphNode3D._get_property_list graph is null")
		return props

	props.append(
		{
			"name": "regenerate",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON | PROPERTY_USAGE_EDITOR,
			"hint_string": "Regenerate"
		}
	)

	#props.append({
		#"name": "Flow Overrides",
		#"type": TYPE_NIL,
		#"usage": PROPERTY_USAGE_GROUP
	#})

	for input : GraphInputParameter in graph.in_params:
		props.append({
			"name": "flow_override/%s/enabled" % input.name,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
		})		
		
		props.append({
			"name": "flow_override/%s/value" % input.name,
			"type": FlowNodeBase.getGdScriptTypeForFlowDataType(input.getDataType()),
			"hint": PROPERTY_USAGE_EDITOR,
			"hint_string": input.name,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
		})

	print( "At FlowGraphNode3D._get_property_list ", props)
	return props
	
func _get(property: StringName) -> Variant:
	var p := String(property)
	if p.begins_with("flow_override/"):
		var parts := p.split("/")
		var id := StringName(parts[1])
		var field := parts[2]
		#print( "Getting override value %s (id:%s field:%s)" % [property, id, field])

		var o := get_or_create_override(id)
		if o:
			if field == "enabled":
				return o.enabled

			if field == "value":
				return o.value
		if _graph:
			if field == "enabled":
				return false
			var input = _graph.findInParamByName( id )
			if input:
				return input.getDefaultValue()
	return null

func _set(property: StringName, value: Variant) -> bool:
	var p := String(property)
	if p.begins_with("flow_override/"):
		var parts := p.split("/")
		var id := StringName(parts[1])
		var field := parts[2]
		
		var o := get_or_create_override(id)
		if not o:
			return true
		print( "Setting override value %s (id:%s field:%s) with %s" % [property, id, field, value])
		
		if field == "enabled":
			o.enabled = value
			return true

		if field == "value":
			o.value = value
			o.enabled = true
			print( "FlowGraphNode.New Input value saved %s" % [value])
			
			var graph_input = graph.findInParamByName( id )
			if graph_input:
				graph_input.notifyChanged()
			regenerate()
				#graph._on_input_changed()
			# Notify the graph the values are dirty
			#graph_node_changed.emit( self, id )
			
			
			return true
			
	return false

func get_or_create_override( id : StringName ) -> FlowGraphParamOverride:
	for o in overrides:
		if o.param_id == id:
			return o
	return null

func regenerate():
	print( "regenerate.Starts %s" % graph )
	graph.compile()
	var ctx = FlowData.EvaluationContext.new()
	for node in graph.input_nodes:
		node.dirty = true
	ctx.graph = graph
	ctx.owner = self
	ctx.trace = true
	ctx.nodes_to_eval = ctx.getEvalOrder( graph.all_nodes )
	ctx.run()
	print( "regenerate.Ends %s" % graph )
	
