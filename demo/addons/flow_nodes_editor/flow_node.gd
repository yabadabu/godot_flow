@tool

## This is the Node3D the user will instantiate in his final 3D scenes to trigger
## the generation of PCG
## It technically should not need to be a Node3D, as the transform is not really used
## but I'm currently generating the spawned nodes as child of this nodes

extends Node3D
class_name FlowGraphNode3D

@export var graph : FlowGraphResource :
	set(new_value):
		if _graph and _graph.in_params_changed.is_connected(_on_graph_inputs_change):
			if Engine.is_editor_hint() and is_inside_tree():
				FlowPlugin.get_instance().unregister_executor(self)
			clearInstances( )
			_graph.in_params_changed.disconnect(_on_graph_inputs_change)
		_graph = new_value
		if _graph:
			_graph.in_params_changed.connect(_on_graph_inputs_change)
		ctx.graph = _graph
		graph_node_changed.emit( self, "graph_resource" )
		#notify_property_list_changed()
		if Engine.is_editor_hint() and is_inside_tree():
			FlowPlugin.get_instance().register_executor(self, self.graph, 0)
	get:
		return _graph
		
var _graph : FlowGraphResource = FlowGraphResource.new()
signal graph_node_changed( graph_node : FlowGraphNode3D, prop_name : String )
var ctx := FlowData.EvaluationContext.new()
var _initialized := false

@export var trace : bool:
	set(new_value):
		ctx.trace = new_value
	get:
		return ctx.trace

@export var overrides: Array[FlowGraphParamOverride] = []
	
func _ready():
	ctx.owner = self
	ctx.graph = _graph
	for o in overrides:
		print( "  Current override %s : %s : %s" % [ o.param_id, o.enabled, o.value ])
	# To ensure the overrides are unique to each instance when copy/pasteing a node in the scene
	if Engine.is_editor_hint() and not _initialized:
		_initialized = true
		duplicateOverrides()
		
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		FlowPlugin.get_instance().register_executor(self, self.graph, 0)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		FlowPlugin.get_instance().unregister_executor(self)
		
func _on_graph_inputs_change():
	print( "_on_graph_inputs_change. Checking existing %d overrides. The graph has %d inputs" % [overrides.size(), graph.in_params.size()] )
	overrides = FlowGraphOverrides.syncWithGraph(graph, overrides)
	ctx.markInputNodesDirty()
	notify_property_list_changed()
	graph_node_changed.emit(self, "graph_inputs")

func _get_property_list() -> Array[Dictionary]:
	var props : Array[Dictionary] = []

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
	props.append(
		{
			"name": "clearInstances",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON | PROPERTY_USAGE_EDITOR,
			"hint_string": "Clear"
		}
	)

	#props.append({
		#"name": "Flow Overrides",
		#"type": TYPE_NIL,
		#"usage": PROPERTY_USAGE_GROUP
	#})

	props.append_array(FlowGraphOverrides.getPropertyList(graph))

	#print( "At FlowGraphNode3D._get_property_list ", props)
	return props
	
func _get(property: StringName) -> Variant:
	return FlowGraphOverrides.getProperty(graph, overrides, property)

func _set(property: StringName, value: Variant) -> bool:
	if not FlowGraphOverrides.setProperty(graph, overrides, property, value):
		return false
	var parts := String(property).split("/")
	var param_id := StringName(parts[1])
	ctx.markInputNodesDirty(param_id)
	graph_node_changed.emit(self, param_id)
	return true

func get_or_create_override( id : StringName ) -> FlowGraphParamOverride:
	return FlowGraphOverrides.getOrCreate(graph, overrides, id)

func duplicateOverrides():
	overrides = FlowGraphOverrides.duplicateAll(overrides)

func clearInstances():
	print( "clearInstances.Starts %s" % graph )
	if ctx.graph:
		for node in ctx.graph.all_nodes:
			ctx.removeRegisteredInstancedNodes( node )

func regenerate():
	# _ready has not yet been called.
	if not ctx.owner or not graph:
		return
	print( "regenerate.Starts %s by %s (%s)" % [ graph, name, graph.compiled ] )
	graph.compile()
	for node in graph.input_nodes:
		ctx.markNodeDirty(node)
	ctx.computeDirtyNodesAndRun()
		
	FlowPlugin.get_instance().register_executor( self, self.graph, 0 )
	print( "regenerate.Ends %s" % graph )
	
