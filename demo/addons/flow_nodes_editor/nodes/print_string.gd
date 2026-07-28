@tool
extends FlowNodeBase

@export var prefix_message: String = "Log:"
@export var attribute_to_print: String = ""

func _init():
	meta_node = {
		"title" : "Print String",
		"category" : "Debug",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Prints a message that outputs a prefixed message optionally to the log.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	
	var prefix = prefix_message
	var attr_name = attribute_to_print
	if attr_name != "":
		var stream = in_data.findStream(attr_name)
		if stream:
			print("%s: Stream '%s' contents: %s" % [prefix, attr_name, str(stream.container)])
		else:
			print("%s: Stream '%s' not found" % [prefix, attr_name])
	else:
		print("%s: Data size = %d" % [prefix, in_data.size()])
		
	setOutput(ctx, 0, in_data)
