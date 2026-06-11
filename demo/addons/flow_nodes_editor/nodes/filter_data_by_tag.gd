@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Filter Data By Tag",
		"settings" : FilterDataByTagNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Inside" }, { "label" : "Outside" }],
		"aliases" : ["Filter Data By Tag"],
		"category" : "Filter",
		"tooltip" : "Separates data according to their tags. You can specify a comma-separated list of Tags to filter by.\nMatches if ANY listed tag is present (OR semantics).",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var filter_tags := []
	var raw_tags = settings.tags.split(",")
	for raw in raw_tags:
		var clean = raw.strip_edges()
		if clean != "":
			filter_tags.append(clean)

	if filter_tags.is_empty():
		setError("tags is empty — set the comma-separated tag list to filter by")
		return

	var match_found = false
	for tag in in_data.tags:
		if tag in filter_tags:
			match_found = true
			break
			
	var empty_data = FlowData.Data.new()
	if match_found:
		set_output(0, in_data)
		set_output(1, empty_data)
	else:
		set_output(0, empty_data)
		set_output(1, in_data)
