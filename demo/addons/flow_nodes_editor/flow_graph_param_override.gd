# FlowParamOverride.gd
@tool
class_name FlowGraphParamOverride
extends Resource

signal value_changed(param_id: StringName, value: Variant)

@export var param_id: StringName
@export var enabled := false:
	set(v):
		enabled = v
		emit_changed()

@export var value: Variant:
	set(v):
		value = v
		emit_changed()
		value_changed.emit(param_id, value)

func getAsFlowData() -> FlowData.Data:
	var data = FlowData.Data.new()
	var data_type := FlowNodeBase.getFlowDataTypeFromObject(value)
	if data_type == FlowData.DataType.Invalid:
		push_warning("Override param %s has unsupported value %s" % [param_id, value])
		return data
	var container = data.addStream(param_id, data_type)
	container.resize(1)
	container[0] = value
	return data
