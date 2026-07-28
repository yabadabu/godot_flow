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

# The input is intentionally hidden from the UI, but unlike an ordinary
# configuration input it must consume the current bulk rather than bulk 0.
func readAllInputsForBulk(
	ctx: FlowData.EvaluationContext,
	bulk_idx: int
) -> void:
	ctx.setNodeInputs(self, [
		_getInputForBulkInContext(ctx, bulk_idx, 0)
	])
