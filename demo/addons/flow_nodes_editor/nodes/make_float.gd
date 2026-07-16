@tool
extends FlowNodeBase

@export var value : float = 0.0

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "Float"

func _init():
	meta_node = {
		"title" : "Make Float",
		"category" : "Math",
		"ins" : [], 
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.Float }],
		"tooltip" : "Creates a single Float value",
		"hide_inputs" : true,
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var container : PackedFloat32Array = output.addStream( out_name, FlowData.DataType.Float )
	container.resize( 1 )
	container[0] = value
	set_output( 0, output )
