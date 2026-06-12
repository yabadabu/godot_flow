@tool
class_name ScanNodesNodeSettings
extends NodeSettings

@export_group("Scan Nodes")

@export var group_name : String
## Filter by node name; supports * and ? wildcards (case-insensitive)
@export var filter_by_name : String
@export var filter_by_class_name : String
## Scan the whole scene tree; when false only direct children of the scene root are inspected
@export var recursive : bool = true
@export var import_metadata : bool = false
@export var import_properties : Array[ StringName ]
@export var size_to_bounds : bool = false

func _init():
	super._init()
	resource_name = "Scan Nodes Settings"
