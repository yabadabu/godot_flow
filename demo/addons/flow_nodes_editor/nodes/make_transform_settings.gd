@tool
class_name MakeTransformNodeSettings
extends NodeSettings

@export_group("Make Transform")

enum eOperation {
	FromTranslationRotationScale
}
			
# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true

@export var operation : eOperation = eOperation.FromTranslationRotationScale:
	set(value):
		if operation != value:
			operation = value
			notify_property_list_changed()

@export var attribute_position : String = "@last"
@export var attribute_rotation : String = "@last"
@export var attribute_scale : String = "@last"
@export var out_name : String = "@source"

func _init():
	super._init()
	resource_name = "Make Transform Settings"
