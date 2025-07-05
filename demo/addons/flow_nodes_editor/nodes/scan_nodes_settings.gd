@tool
class_name ScanNodesNodeSettings
extends NodeSettings

@export_group("Scan Nodes")

@export var group_name : String
@export var import_metadata : bool = false

func _init():
	super._init()
	resource_name = "Scan Nodes Settings"
