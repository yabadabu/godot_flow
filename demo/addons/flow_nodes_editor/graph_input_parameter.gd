@tool
class_name GraphInputParameter
extends Resource

@export var name : String = "arg_name"
@export var data_type : FlowData.DataType = FlowData.DataType.Float:
	set(new_value):
		data_type = new_value
		emit_changed()
		notify_property_list_changed()
		
# Default value when type is a bool
@export var cte_bool: bool = false
@export var cte_int: int = 0
@export var cte_float : float = 0.0
@export var cte_vector : Vector3 = Vector3.ZERO
@export var cte_resource : Resource
@export var cte_string : String = ""

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
