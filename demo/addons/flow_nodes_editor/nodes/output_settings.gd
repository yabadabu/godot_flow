@tool
class_name OutputNodeSettings
extends NodeSettings

@export_group("Output")

@export var name : String = "Out"
@export var data_type : FlowData.DataType = FlowData.DataType.Invalid

func _init():
	super._init()
	resource_name = "Output"
