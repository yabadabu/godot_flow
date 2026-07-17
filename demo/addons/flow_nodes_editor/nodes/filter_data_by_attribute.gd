@tool
extends FlowNodeBase

@export var attribute_name: String

enum eCondition {
	ExactMatch,
	StartsWith,
	AnyWhere
	}
@export var condition : eCondition = eCondition.ExactMatch

func _init():
	meta_node = {
		"title" : "Filter Data By Attribute",
		"category" : "Filter",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Inside" }, { "label" : "Outside" }],
		"tooltip" : "Separates data based on whether they have a specified metadata attribute.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
		
	var attr_name : String = attribute_name
	var match_found := false
	
	match condition:
		eCondition.ExactMatch:
			match_found = in_data.hasStream(attr_name)
		eCondition.StartsWith:
			var names = in_data.streams.keys()
			match_found = names.any(func(c): return c.begins_with(attr_name))
		eCondition.AnyWhere:
			var names = in_data.streams.keys()
			match_found = names.any(func(c): return c.contains(attr_name))

	if match_found:
		set_output(0, in_data)
		set_output(1, FlowData.Data.new())
	else:
		set_output(0, FlowData.Data.new())
		set_output(1, in_data)
