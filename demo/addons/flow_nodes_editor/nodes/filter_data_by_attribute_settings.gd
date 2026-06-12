@tool
class_name FilterDataByAttributeNodeSettings
extends NodeSettings

@export_group("Filter Data By Attribute")

@export var attribute_name: String

enum eCondition {
	ExactMatch,
	StartsWith,
	AnyWhere
	}
@export var condition : eCondition = eCondition.ExactMatch

func _init():
	super._init()
	resource_name = "Filter Data By Attribute"
