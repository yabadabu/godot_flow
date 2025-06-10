@tool
class_name AssetsNodeSettings
extends NodeSettings

@export_group("Assets")

@export var assets : Array[ FlowUserResourceData ] = []

func _init():
	super._init()
	resource_name = "Assets Settings"
