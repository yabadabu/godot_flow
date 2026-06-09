@tool
extends NodeSettings

@export_group("Attribute Rename")
@export var from_name : String = "@last"
@export var to_name : String = ""
@export var overwrite_existing : bool = false

func _init():
	super._init()
	resource_name = "Attribute Rename Settings"
