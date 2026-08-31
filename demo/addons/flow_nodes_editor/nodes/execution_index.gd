@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Execution Index",
		"category" : "Metadata",
		"ins" : [],
		"outs" : [{
			"label" : "Execution Index",
			"data_type" : FlowData.DataType.Int,
		}],
		"tooltip" : "Returns the invocation index of the current evaluation context",
		"keywords" : ["iteration", "invocation", "loop index"],
	}

func execute(ctx : FlowData.EvaluationContext):
	var output := FlowData.Data.new()
	var container := PackedInt32Array([ctx.execution_index])
	output.registerStream("execution_index", container, FlowData.DataType.Int)
	setOutput(ctx, 0, output)
