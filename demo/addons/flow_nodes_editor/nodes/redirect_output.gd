@tool
class_name FlowNodeRedirectOutput
extends FlowNodeRedirectEndpoint

func _init() -> void:
	meta_node = {
		"title": "Redirect Output",
		"category": "Control Flow",
		"ins": [],
		"outs": [{
			"label": "Out",
			"data_type": FlowData.DataType.Any,
		}],
		"tooltip": "Retrieves all bulks sent to this named redirector.",
		"auto_register": false,
		"hide_inputs": true,
	}

# Forward every bulk produced by every input endpoint. There is no fallback
# bulk: if all redirect inputs produce nothing, this endpoint produces nothing.
func run(ctx: FlowData.EvaluationContext) -> void:
	for connection in deps:
		var source_node := ctx.graph.nodes_by_name.get(connection.from_node)
		if not source_node:
			continue
		for bulk_idx in range(ctx.getOutputBulks(source_node).size()):
			var data := ctx.getOutput(
				source_node,
				bulk_idx,
				connection.from_port
			)
			ctx.setNodeInputs(self, [data])
			setOutput(ctx, 0, data)

func executedDisabled(_ctx: FlowData.EvaluationContext) -> void:
	pass
