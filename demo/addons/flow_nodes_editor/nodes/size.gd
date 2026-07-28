@tool
extends FlowNodeBase

@export var out_name : String = "count"

func _init():
	meta_node = {
		"title" : "Size",
		"category" : "Metadata",
		"ins" : [{ "label" : "In"}],
		"outs" : [{ "label" : "Size", "data_type" : FlowData.DataType.Int }],
		"tooltip" : "Returns the current size of the input sequence",
	}
	
func execute( ctx : FlowData.EvaluationContext ):
	var input: FlowData.Data = getInput(ctx, 0)
	var output := FlowData.Data.new()
	var container = PackedInt32Array()
	container.append( input.size() )
	output.registerStream( out_name, container )
	setOutput(ctx, 0, output )
