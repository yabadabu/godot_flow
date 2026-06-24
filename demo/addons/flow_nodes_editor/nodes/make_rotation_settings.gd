@tool
class_name MakeRotationNodeSettings
extends NodeSettings

@export_group("Make Rotation")

enum eOperation {
	From_Z,
	From_Z_And_Y,
	From_Axis_And_Angle,
	#FromEulerAngles
}

			
# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true

@export var operation : eOperation = eOperation.From_Z:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()

@export var attribute_z : String = "@last"
@export var attribute_y : String = "@last"
@export var axis_y : Vector3 = Vector3.UP

@export var axis : String = "@last"
@export var angle : String = "@last"

@export var out_name : String = "NewRotation"

func _init():
	super._init()
	resource_name = "Make Rotation Settings"

func exposeParam( name : String ) -> bool:
	var arg_from_z = name == "axis_y" or name == "attribute_z"
	var arg_from_z_and_y = name == "attribute_y" or name == "attribute_z"
	var arg_from_axis_and_angle = name == "axis" or name == "angle"
	if name == "operation" or name == "out_name":
		return true
	if arg_from_z or arg_from_z_and_y or arg_from_axis_and_angle:
		if operation == eOperation.From_Z:
			return arg_from_z
		elif operation == eOperation.From_Z_And_Y:
			return arg_from_z_and_y
		elif operation == eOperation.From_Axis_And_Angle:
			return arg_from_axis_and_angle
	return true
