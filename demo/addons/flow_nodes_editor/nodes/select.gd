@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Select",
		"settings" : SelectNodeSettings,
		"aliases" : ["Select"],
		"category" : "ControlFlow",
		"ins" : [{ "label": "In A" }, { "label": "In B" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Selects one of two inputs to be forwarded to a single output based on a Boolean attribute or value.\nThe selection is constant per evaluation: in attribute mode only element [0] of the attribute is read\n(from input A if available, else B) — there is no per-point selection.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_dataA : FlowData.Data = get_optional_input(0)
	var in_dataB : FlowData.Data = get_optional_input(1)

	var select_b : bool = settings.select_b
	if settings.use_attribute and settings.attribute_name != "":
		var data_source = in_dataA if in_dataA else in_dataB
		if data_source:
			var stream = data_source.findStream(settings.attribute_name)
			if stream and stream.container.size() > 0:
				var val = stream.container[0]
				if val is bool or val is int or val is float:
					select_b = bool(val)
				else:
					var sval := str(val).strip_edges().to_lower()
					select_b = sval == "true" or sval == "1" or sval == "yes"

	var selected_data = in_dataB if select_b else in_dataA
	if selected_data == null:
		selected_data = FlowData.Data.new()
	set_output(0, selected_data)
