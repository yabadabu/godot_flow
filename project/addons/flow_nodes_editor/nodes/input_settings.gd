@tool
class_name InputNodeSettings
extends NodeSettings

@export_group("Input")

@export var name : String
@export var data_type : FlowData.DataType

func _init():
	super._init()
	resource_name = "Input"
