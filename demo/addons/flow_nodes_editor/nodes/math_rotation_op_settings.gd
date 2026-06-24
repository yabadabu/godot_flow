@tool
class_name MathRotationOpNodeSettings
extends NodeSettings

@export_group("Rotation Op")

enum eOperation {
	Combine,
	Invert,
	Lerp,
}

@export var operation : eOperation = eOperation.Lerp:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
@export var in_nameA : String = "@last"
@export var in_nameB : String = "@last"
@export var in_nameC : String = "@last"
@export var out_name : String = "@Source"

func _init():
	super._init()
	resource_name = "Rotation Op"

func isSingleArgument( ) -> bool:
	return operation == eOperation.Invert or \
	   false

func isTriArgument( ) -> bool:
	return operation == eOperation.Lerp or \
	   false

func exposeParam( name : String ) -> bool:
	if name == "in_nameB":
		return not isSingleArgument()
	return true
