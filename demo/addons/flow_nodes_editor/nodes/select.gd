@tool
extends FlowNodeBase

@export var select_b: bool = false
@export var use_attribute: bool = false
@export var attribute_name: String = ""

func _init():
	meta_node = {
		"title" : "Select",
		"category" : "Control Flow",
		"ins" : [{ "label": "In A" }, { "label": "In B" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Selects one of two inputs to be forwarded to a single output based on a Boolean attribute or value.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_dataA : FlowData.Data = get_input(0)
	var in_dataB : FlowData.Data = get_optional_input(1)
	
	var select_b : bool = select_b
	if use_attribute and attribute_name != "":
		var data_source = in_dataA if in_dataA else in_dataB
		if data_source:
			var stream = data_source.findStream(attribute_name)
			if stream and stream.container.size() > 0:
				var val = stream.container[0]
				if val is bool or val is int or val is float:
					select_b = bool(val)
				else:
					select_b = str(val).to_lower() == "true"
	
	var selected_data = in_dataB if select_b else in_dataA
	if selected_data == null:
		selected_data = FlowData.Data.new()
	set_output(0, selected_data)
