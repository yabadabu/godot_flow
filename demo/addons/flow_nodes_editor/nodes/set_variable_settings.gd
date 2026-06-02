@tool
class_name SetVariableNodeSettings
extends NodeSettings

@export_group("Set Variable")

@export var variable_name : String = "variable"
@export var node_color : Color = Color("22d3ee")

func _init():
	super._init()
	resource_name = "Set Variable"
