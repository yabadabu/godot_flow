@tool
class_name FlowNodeRedirectInput
extends FlowNodeRedirectEndpoint

func _init() -> void:
	meta_node = {
		"title": "Redirect Input",
		"category": "Control Flow",
		"ins": [{
			"label": "In",
			"data_type": FlowData.DataType.Any,
			"multiple_connections": true,
		}],
		"outs": [],
		"tooltip": "Sends all connected bulks to the outputs of this named redirector.",
		"auto_register": false,
		"hide_inputs": true,
	}

# Unlike ordinary disabled nodes, a disabled redirect input cuts this branch
# instead of passing its inputs through.
func executedDisabled(_ctx: FlowData.EvaluationContext) -> void:
	pass
