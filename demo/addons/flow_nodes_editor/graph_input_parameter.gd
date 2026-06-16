@tool
class_name GraphInputParameter
extends Resource

# An graph input with has a type and a constant value

@export var name : String = "arg_name"
var change_id : int = 0

@export var is_constant : bool = true:
	set(new_value):
		is_constant = new_value
		notifyChanged()
		notify_property_list_changed()
		
@export var data_type : FlowData.DataType = FlowData.DataType.Float:
	set(new_value):
		data_type = new_value
		notifyChanged()
		notify_property_list_changed()
		
# Default value when type is a bool
@export var cte_bool: bool = false:
	set(new_value):
		cte_bool = new_value
		notifyChanged()

@export var cte_int: int = 0:
	set(new_value):
		cte_int = new_value
		notifyChanged()
		
@export var cte_float : float = 0.0:
	set(new_value):
		cte_float = new_value
		notifyChanged()
		
@export var cte_vector : Vector3 = Vector3.ZERO:
	set(new_value):
		cte_vector = new_value
		notifyChanged()
	
@export var cte_resource : Resource:
	set(new_value):
		cte_resource = new_value
		notifyChanged()

@export var cte_string : String = "":
	set(new_value):
		cte_string = new_value
		notifyChanged()

func notifyChanged():
	change_id += 1
	print( "GraphInput %s changed (%d)" % [ name, change_id ] )
	emit_changed()

func getDataType() -> FlowData.DataType:
	if is_constant:
		return data_type
	return FlowData.DataType.Invalid

func getDefaultValue():
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
	push_error( "InputParam.%s.getDefaultValue. Invalid data_type %s" % [ name, data_type]  )
	return null

func getAsFlowData() -> FlowData.Data:
	var data = FlowData.Data.new()
	var container = data.addStream( name, getDataType() )
	if container != null:
		container.resize( 1 )
		container[0] = getDefaultValue()
	return data
