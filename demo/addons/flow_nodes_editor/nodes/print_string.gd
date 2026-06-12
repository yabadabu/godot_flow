@tool
extends FlowNodeBase

const MAX_PRINTED_VALUES := 100

func _init():
	meta_node = {
		"title" : "Print String",
		"settings" : PrintStringNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Print String"],
		"category" : "Debug",
		"tooltip" : "Debug pass-through: prints the contents of the chosen attribute (or the point count when no attribute is set) to the output log, prefixed with the message, then forwards the input unchanged.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var prefix = settings.prefix_message
	var attr_name = settings.attribute_to_print
	if attr_name != "":
		var stream = in_data.findStream(attr_name)
		if stream:
			var n : int = stream.container.size()
			if n > MAX_PRINTED_VALUES:
				print("%s: Stream '%s' contents (first %d of %d): %s ..." % [prefix, attr_name, MAX_PRINTED_VALUES, n, str(stream.container.slice(0, MAX_PRINTED_VALUES))])
			else:
				print("%s: Stream '%s' contents: %s" % [prefix, attr_name, str(stream.container)])
		else:
			print("%s: Stream '%s' not found" % [prefix, attr_name])
	else:
		print("%s: Data size = %d" % [prefix, in_data.size()])

	set_output(0, in_data)
