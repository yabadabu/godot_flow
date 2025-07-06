@tool
class_name SelfPruningSettings
extends NodeSettings

@export_group("Self Pruning")

@export var keep_self_intersections : bool = false

func _init():
	super._init()
	resource_name = "Self Pruning"
