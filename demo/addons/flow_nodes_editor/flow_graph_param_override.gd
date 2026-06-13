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

var value: Variant:
	set(v):
		value = v
		emit_changed()
		value_changed.emit(param_id, value)

func getAsFlowData() -> FlowData.Data:
	var data = FlowData.Data.new()
	var container = data.addStream( param_id, FlowData.DataType.Int )
	container.resize( 1 )
	container[0] = int(value)
	return data
