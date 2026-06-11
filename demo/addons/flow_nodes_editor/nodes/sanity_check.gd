@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Sanity Check Point Data",
		"settings" : SanityCheckNodeSettings,
		"aliases" : ["Sanity Check Point Data", "Assert", "Validate"],
		"category" : "Debug",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Validates that the input data point(s) have a value in the given range.\nOnly numeric (Int/Float/Bool) attributes can be checked.\nAn empty attribute name disables the check (pure pass-through).",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input( 0, ctx, "Input 'In'" )
	if in_data == null:
		return

	var attr_name = settings.attribute_name
	if attr_name != "":
		var stream = in_data.findStream(attr_name)
		if stream == null:
			setError("Sanity check failed: Attribute '%s' not found" % attr_name)
			return
		if stream.data_type != FlowData.DataType.Int and stream.data_type != FlowData.DataType.Float and stream.data_type != FlowData.DataType.Bool:
			setError("Sanity check failed: Attribute '%s' is not numeric (Int/Float/Bool), nothing can be validated" % attr_name)
			return

		var container = stream.container
		var min_val = settings.min_value
		var max_val = settings.max_value
		for i in container.size():
			var val = container[i]
			if val is int or val is float:
				var f_val = float(val)
				if f_val < min_val or f_val > max_val:
					setError("Sanity check failed: Element %d has value %f, which is outside range [%f, %f]" % [i, f_val, min_val, max_val])
					return

	set_output(0, in_data)
