@tool
extends FlowNodeBase

@export var x_attribute: String = ""
@export var y_attribute: String = ""
@export var z_attribute: String = ""
@export var default_value: Vector3 = Vector3.ONE
@export var out_attribute: String = "size"

func _init():
	meta_node = {
		"title" : "Compose Vector",
		"category" : "Metadata",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Composes a Vector3 attribute from float attributes or default values.\nCan NOT use constant values like 2.5 on the attribute name",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
		
	var out_data : FlowData.Data = in_data.duplicate()
	var size = in_data.size()
	
	var sx = in_data.findStream(x_attribute) if x_attribute != "" else null
	var sy = in_data.findStream(y_attribute) if y_attribute != "" else null
	var sz = in_data.findStream(z_attribute) if z_attribute != "" else null
	
	var out_vec := PackedVector3Array()
	out_vec.resize(size)
	
	for i in range(size):
		var vx = sx.container[i] if sx else default_value.x
		var vy = sy.container[i] if sy else default_value.y
		var vz = sz.container[i] if sz else default_value.z
		out_vec[i] = Vector3(vx, vy, vz)
		
	var err = out_data.registerStream(out_attribute, out_vec, FlowData.DataType.Vector)
	if err:
		setError(err)
		return
		
	set_output(0, out_data)
