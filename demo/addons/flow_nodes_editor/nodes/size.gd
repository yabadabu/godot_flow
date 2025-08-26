@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Size",
		"settings" : SizeNodeSettings,
		"ins" : [{ "label" : "In"}],
		"outs" : [{ "label" : "Size", "data_type" : FlowData.DataType.Int }],
		"tooltip" : "Returns the current size of the input sequence",
	}
	
func execute( ctx : FlowData.EvaluationContext ):
	var input: FlowData.Data = get_input(0)
	var output := FlowData.Data.new()
	var container = PackedInt32Array()
	container.append( input.size() )
	output.registerStream( settings.out_name, container )
	set_output( 0, output )
