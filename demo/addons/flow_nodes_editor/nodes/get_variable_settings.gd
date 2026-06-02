@tool
class_name GetVariableNodeSettings
extends NodeSettings

@export_group("Get Variable")

@export var variable_name : String = ""

func _init():
	super._init()
	resource_name = "Get Variable"

func _get_variable_selector_props() -> Array[Dictionary]:
	return [{ "prop": "variable_name" }]
