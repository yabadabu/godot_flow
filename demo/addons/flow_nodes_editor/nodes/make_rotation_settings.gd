@tool
class_name MakeRotationNodeSettings
extends NodeSettings

@export_group("Make Rotation")

enum eOperation {
	FromZ_And_Y,
	FromAxis,
	FromEulerAngles
}

@export var operation : eOperation = eOperation.FromZ_And_Y:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()

@export var Y : Vector3 = Vector3.UP
@export var attribute_Z : String = "@last"

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "NewRotation"

func _init():
	super._init()
	resource_name = "Make Rotation Settings"
