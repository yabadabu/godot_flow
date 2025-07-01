@tool
extends Resource
class_name FlowGraphResource
@export_category("Flow Graph Resource")

@export var nodes: Array[Dictionary] = []
@export var conns : Array[Dictionary] = []
@export var view_zoom : float = 1.0
@export var view_offset : Vector2 = Vector2(0,0)
@export var new_name_counter : int = 0
@export var inputs : GraphInputParameters = GraphInputParameters.new()
