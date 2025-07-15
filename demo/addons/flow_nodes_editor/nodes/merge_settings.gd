@tool
class_name MergeNodeSettings
extends NodeSettings

@export_group("Merge")

@export var merge_only_common_attributes := false

func _init():
	super._init()
	resource_name = "Merge Settings"
