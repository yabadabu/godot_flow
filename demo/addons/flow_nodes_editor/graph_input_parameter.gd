@tool
class_name GraphInputParameter
extends Resource

# An graph input with has a type and a constant value

@export var name : String = "arg_name"

@export var is_constant : bool = true:
	set(new_value):
		is_constant = new_value
		emit_changed()
		notify_property_list_changed()
		
@export var data_type : FlowData.DataType = FlowData.DataType.Float:
	set(new_value):
		data_type = new_value
		emit_changed()
		notify_property_list_changed()
		
# Default value when type is a bool
@export var cte_bool: bool = false:
	set(new_value):
		cte_bool = new_value
		emit_changed()

@export var cte_int: int = 0:
	set(new_value):
		cte_int = new_value
		emit_changed()
		
@export var cte_float : float = 0.0:
	set(new_value):
		cte_float = new_value
		emit_changed()
		
@export var cte_vector : Vector3 = Vector3.ZERO:
	set(new_value):
		cte_vector = new_value
		emit_changed()
	
@export var cte_resource : Resource:
	set(new_value):
		cte_resource = new_value
		emit_changed()

@export var cte_string : String = "":
	set(new_value):
		cte_string = new_value
		emit_changed()

func getDataType() -> FlowData.DataType:
	if is_constant:
		return data_type
	return FlowData.DataType.Invalid

func get_default_value():
	match data_type:
		FlowData.DataType.Bool:
			return cte_bool
		FlowData.DataType.Int:
			return cte_int
		FlowData.DataType.Float:
			return cte_float
		FlowData.DataType.Vector:
			return cte_vector
		FlowData.DataType.Resource:
			return cte_resource
		FlowData.DataType.String:
			return cte_string
	return null
