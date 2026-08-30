@tool
extends FlowNodeBase

@export_file var value : String = "str"

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "String"

func _init():
	meta_node = {
		"title" : "Make String",
		"category" : "Math",
		"ins" : [], 
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.String }],
		"tooltip" : "Creates a single String value",
		"hide_inputs" : true,
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var container : PackedStringArray = output.addStream( out_name, FlowData.DataType.String )
	container.resize( 1 )
	container[0] = value
	setOutput(ctx, 0, output )
