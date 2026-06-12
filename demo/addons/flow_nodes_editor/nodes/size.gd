@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Size",
		"settings" : SizeNodeSettings,
		"aliases" : ["Count", "Num Points"],
		"category" : "Utility",
		"ins" : [{ "label" : "In"}],
		"outs" : [{ "label" : "Size", "data_type" : FlowData.DataType.Int }],
		"tooltip" : "Returns the current size (point count) of the input sequence as a single-entry Int attribute.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var input: FlowData.Data = require_input( 0, ctx )
	if input == null:
		return
	var output := FlowData.Data.new()
	var container = PackedInt32Array()
	container.append( input.size() )
	output.registerStream( settings.out_name, container, FlowData.DataType.Int )
	set_output( 0, output )
