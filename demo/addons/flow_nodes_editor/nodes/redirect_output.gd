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
