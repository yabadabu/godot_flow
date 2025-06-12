@tool
class_name GraphInputParameter
extends Resource

@export var name : String = "arg_name"
@export var data_type : FlowData.DataType = FlowData.DataType.Float:
	set(new_value):
		data_type = new_value
		notify_property_list_changed()
		
@export var cte_bool: bool = false
@export var cte_float : float = 0.0
@export var cte_vector : Vector3 = Vector3.ZERO
@export var cte_resource : Resource
@export var cte_string : String = ""
