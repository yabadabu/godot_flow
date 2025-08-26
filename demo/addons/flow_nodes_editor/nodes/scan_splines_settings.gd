@tool
class_name ScanSplinesNodeSettings
extends NodeSettings

@export_group("Scan Splines")

@export var group_name : String
@export var filter_by_class_name : String
@export var required_meta_bool : StringName

func _init():
	super._init()
	resource_name = "Scan Splines Settings"
