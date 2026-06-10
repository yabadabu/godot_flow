@tool
class_name FilterNodeSettings
extends NodeSettings

@export_group("Filter")

enum eCondition {
	Equal,
	NotEqual,
	Greater,
	GreaterOrEqual,
	Less,
	LessOrEqual,
	AlmostEqual,
	LogicalAND,
	LogicalOR,
	LogicalXOR,
	IsNull,
	BetweenExcludingMinMax,
	BetweenIncludingMinMax,
	BetweenIncludingMin,
	BetweenIncludingMax,
}

@export var in_nameA : String = "@last"
@export var condition : eCondition = eCondition.Equal:
	set(value):
		if condition != value:
			condition = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
@export var in_nameB : String = "@last"
@export var threshold : float = 0.1
@export var in_nameC : String = "@last"

func _init():
	super._init()
	resource_name = "Filter Settings"

func isLogicalOp() -> bool:
	return condition == eCondition.LogicalAND \
		|| condition == eCondition.LogicalOR  \
		|| condition == eCondition.LogicalXOR

func isBetweenCondition() -> bool:
	return condition >= eCondition.BetweenExcludingMinMax and condition <= eCondition.BetweenIncludingMax

func exposeParam(name : String) -> bool:
	if name == "in_nameC":
		return isBetweenCondition()
	if name == "threshold":
		return condition == eCondition.AlmostEqual
	return true
