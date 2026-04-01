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
	IsNull
}

@export var in_nameA : String = "@last"
@export var condition : eCondition = eCondition.Equal
@export var in_nameB : String = "@last"
@export var threshold : float = 0.1

func _init():
	super._init()
	resource_name = "Filter Settings"

func isLogicalOp() -> bool:
	return condition == eCondition.LogicalAND \
		|| condition == eCondition.LogicalOR  \
		|| condition == eCondition.LogicalXOR
