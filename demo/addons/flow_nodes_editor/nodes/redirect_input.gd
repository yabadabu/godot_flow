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
		"auto_register": true,
		"hide_inputs": true,
	}
