@tool
extends FlowNodeBase

@export var attribute_name: String = "density"
@export var min_value: float = 0.0
@export var max_value: float = 1.0

func _init():
	meta_node = {
		"title" : "Sanity Check Point Data",
		"category" : "Debug",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Validates that the input data point(s) have a value in the given range.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
		
	var attr_name = attribute_name
	if attr_name != "":
		var stream = in_data.findStream(attr_name)
		if stream == null:
			setError(ctx, "Sanity check failed: Attribute '%s' not found" % attr_name)
			return
		
		var container = stream.container
		var min_val = min_value
		var max_val = max_value
		for i in container.size():
			var val = container[i]
			if val is int or val is float:
				var f_val = float(val)
				if f_val < min_val or f_val > max_val:
					setError(ctx, "Sanity check failed: Element %d has value %f, which is outside range [%f, %f]" % [i, f_val, min_val, max_val])
					return
					
	setOutput(ctx, 0, in_data)
