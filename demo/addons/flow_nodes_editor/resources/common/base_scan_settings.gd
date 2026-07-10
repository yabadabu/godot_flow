@tool
class_name BaseScanNodeSettings
extends NodeSettings

@export_group("Scan Nodes")

@export var group_name : String
@export var filter_by_name : String
@export var import_metadata : bool = false
@export var import_properties : Array[ StringName ]
@export var required_meta_bool : StringName
