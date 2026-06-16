@tool
class_name SubgraphNodeSettings
extends NodeSettings

@export_group("Subgraph")

@export var graph : FlowGraphResource :
	set(value):
		_graph = value
		emit_changed()
	get():
		return _graph
		
var _graph : FlowGraphResource = FlowGraphResource.new()

func _init():
	super._init()
	resource_name = "Subgraph"
