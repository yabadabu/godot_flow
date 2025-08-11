@tool
class_name SequenceSampleNodeSettings
extends NodeSettings

@export_group("Sequence Sample")

@export var start : int = 0
@export var count : int = 0
@export var step : int = 1
#@export var wrap_around : bool = false

func _init():
	super._init()
	resource_name = "Sequence Sample Settings"
