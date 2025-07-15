@tool
class_name RemoveAttributeNodeSettings
extends NodeSettings

@export_group("Remove Attribute")

@export var names : Array[String] = []
@export var keep_selected_attributes : bool = false

func _init():
	super._init()
	resource_name = "Remove Attribute Settings"
