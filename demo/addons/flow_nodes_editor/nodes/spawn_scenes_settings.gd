@tool
class_name SpawnScenesNodeSettings
extends NodeSettings

@export_group("Spawn Scenes")

@export var scene : PackedScene
@export var scene_attribute : String
@export var assign_attributes: Dictionary

func _init():
	super._init()
	resource_name = "Spawn Scenes Settings"
