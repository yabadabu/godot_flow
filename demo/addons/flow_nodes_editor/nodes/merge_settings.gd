@tool
class_name MergeNodeSettings
extends NodeSettings

@export_group("Merge")

#@export var merge_all_attributes := true

func _init():
	super._init()
	resource_name = "Merge Settings"
