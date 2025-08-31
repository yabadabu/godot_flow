@tool
class_name PartitionNodeSettings
extends NodeSettings

@export_group("Partition")

@export var attribute_name : String = "@last"
@export var out_partition_attribute : String

func _init():
	super._init()
	resource_name = "Partition"
