@tool
extends FlowNodeBase

const AttributeRandomNodeSettings = preload("res://addons/flow_nodes_editor/nodes/attribute_random_settings.gd")

func _init():
	meta_node = {
		"title" : "Attribute Random",
		"settings" : AttributeRandomNodeSettings,
		"category" : "Metadata",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Sets an attribute on points to random values or sequential indices.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
		
	var out_data : FlowData.Data = in_data.duplicate()
	var size := in_data.size()
	
	if settings.data_type == AttributeRandomNodeSettings.eType.Int:
		var container := PackedInt32Array()
		container.resize(size)
		var imin := int(settings.min_value)
		var imax := int(settings.max_value)
		for i in range(size):
			container[i] = rng.randi_range(imin, imax)
		out_data.registerStream(settings.attribute_name, container, FlowData.DataType.Int)
	else:
		var container := PackedFloat32Array()
		container.resize(size)
		for i in range(size):
			container[i] = rng.randf_range(settings.min_value, settings.max_value)
		out_data.registerStream(settings.attribute_name, container, FlowData.DataType.Float)
		
	set_output(0, out_data)
