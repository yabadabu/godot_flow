@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Output",
		"settings" : OutputNodeSettings,
		"category" : "Control Flow",
		"ins" : [{ "label" : "Out" }],
		"outs" : [],
		"tooltip" : "Defines the output of the graph as when used as subgraphs or loop",
		"auto_register" : true,
		"hide_inputs" : true,
		"is_final" : true,
	}
	
func getTitle() -> String:
	return settings.name
