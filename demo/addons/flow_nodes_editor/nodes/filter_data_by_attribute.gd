@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Filter Data By Attribute",
		"settings" : FilterDataByAttributeNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Inside" }, { "label" : "Outside" }],
		"aliases" : ["Filter Data By Attribute"],
		"category" : "Filter",
		"tooltip" : "Separates data based on whether they have a specified metadata attribute.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var attr_name = settings.attribute_name
	if attr_name == "":
		setError("attribute_name is empty — set the attribute to filter by")
		return
	var match_found = in_data.hasStream(attr_name)

	var empty_data = FlowData.Data.new()
	if match_found:
		set_output(0, in_data)
		set_output(1, empty_data)
	else:
		set_output(0, empty_data)
		set_output(1, in_data)
