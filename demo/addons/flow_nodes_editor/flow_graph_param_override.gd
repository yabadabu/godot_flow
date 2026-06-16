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
	
	if typeof( value ) == TYPE_FLOAT:
		var container = data.addStream( param_id, FlowData.DataType.Float )
		container.resize( 1 )
		if value == null:
			container[0] = 0.0
		else:
			container[0] = float(value)
	
	elif typeof( value ) == TYPE_INT:
		var container = data.addStream( param_id, FlowData.DataType.Int )
		container.resize( 1 )
		if value == null:
			container[0] = 0.0
		else:
			container[0] = int(value)
			
	else:
		push_warning( "Override param %s -> %s" % [ param_id, value ])	
		
	return data
