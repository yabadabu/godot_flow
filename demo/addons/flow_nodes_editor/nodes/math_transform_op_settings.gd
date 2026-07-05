@tool
class_name MathTrasformOpNodeSettings
extends NodeSettings

@export_group("Transform Op")

enum eOperation {
	Transform_Location,
	Transform_Direction,
}

@export var attribute_transform : String = "@last"

@export var operation : eOperation = eOperation.Transform_Location:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
func _init():
	super._init()
	resource_name = "Transform Op Settings"
