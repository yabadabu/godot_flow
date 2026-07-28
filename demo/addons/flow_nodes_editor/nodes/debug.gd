@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Debug",
		"category" : "Debug",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"is_final" : true,
		"tooltip" : "Forces the visualization of the debug node. Used when some specific values are required in the debug options.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data = getInput(ctx,  0 )
	debug_enabled = true
	setOutput(ctx, 0, in_data)
