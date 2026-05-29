@tool
extends FlowNodeBase

## A simple pass-through reroute point for organizing graph wires.
## Data flows in and out unchanged — purely for visual wire management.

func _init():
	meta_node = {
		"title" : "•",
		"settings" : NodeSettings,
		"ins" : [{ "label" : "", "data_type" : FlowData.DataType.Invalid }],
		"outs" : [{ "label" : "", "data_type" : FlowData.DataType.Invalid }],
		"tooltip" : "Reroute point — passes data through unchanged",
		"hide_inputs" : false
	}

func getTitle() -> String:
	return ""

func execute( ctx : FlowData.EvaluationContext ):
	var in_data = get_optional_input(0)
	if in_data:
		set_output(0, in_data)
	else:
		set_output(0, FlowData.Data.new())

func _ready():
	super._ready()
	# Make the reroute node compact
	custom_minimum_size = Vector2(30, 30)
