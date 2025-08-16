@tool
class_name MatchAndSetNodeSettings
extends NodeSettings

@export_group("Match And Set")

@export var match_attr : String
@export var weight_attr : String

func _init():
	super._init()
	resource_name = "Match And Set"
