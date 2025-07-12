@tool
class_name SortNodeSettings
extends NodeSettings

@export_group("Sort")

@export var sort_by : String
@export var reverse_descending : bool = false

func _init():
	super._init()
	resource_name = "Sort Settings"

