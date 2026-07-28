@tool
extends FlowNodeBase

@export var attribute_name: String = "random_attr"

enum eType { Float, Int }
@export var data_type: eType = eType.Float

@export var min_value: float = 0.0
@export var max_value: float = 1.0

func _init():
	meta_node = {
		"title" : "Attribute Random",
		"category" : "Metadata",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Sets an attribute on points to random values or sequential indices.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
		
	var out_data : FlowData.Data = in_data.duplicate()
	var size := in_data.size()
	
	if data_type == eType.Int:
		var container := PackedInt32Array()
		container.resize(size)
		var imin := int(min_value)
		var imax := int(max_value)
		for i in range(size):
			container[i] = rng.randi_range(imin, imax)
		out_data.registerStream(attribute_name, container, FlowData.DataType.Int)
	else:
		var container := PackedFloat32Array()
		container.resize(size)
		for i in range(size):
			container[i] = rng.randf_range(min_value, max_value)
		out_data.registerStream(attribute_name, container, FlowData.DataType.Float)
		
	setOutput(ctx, 0, out_data)
