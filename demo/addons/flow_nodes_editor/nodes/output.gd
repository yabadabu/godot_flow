@tool
extends FlowNodeBase

@export var out_name : String = "Out"
@export var data_type : FlowData.DataType = FlowData.DataType.Invalid

func _init():
	meta_node = {
		"title" : "Output",
		"category" : "Control Flow",
		"ins" : [{ "label" : "Out" }],
		"outs" : [],
		"tooltip" : "Defines the output of the graph as when used as subgraphs or loop",
		"auto_register" : true,
		"hide_inputs" : true,
		"is_final" : true,
	}
