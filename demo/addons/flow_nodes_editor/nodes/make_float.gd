@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Make Float",
		"settings" : MakeFloatNodeSettings,
		"category" : "Math",
		"ins" : [], 
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.Float }],
		"tooltip" : "Creates a single Float value",
		"hide_inputs" : true,
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var container : PackedFloat32Array = output.addStream( settings.out_name, FlowData.DataType.Float )
	container.resize( 1 )
	container[0] = settings.value
	set_output( 0, output )
