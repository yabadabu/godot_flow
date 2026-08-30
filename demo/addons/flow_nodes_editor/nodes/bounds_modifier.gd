@tool
extends FlowNodeBase

enum eMode { Set, Add, Multiply, AddPadding }
			
@export var mode: eMode = eMode.Set:
	set(value):
		if mode != value:
			mode = value
			notify_property_list_changed()
			
@export var bounds_min: Vector3 = -Vector3.ONE * 0.5
@export var bounds_max: Vector3 = Vector3.ONE * 0.5
@export var padding: Vector3 = Vector3.ONE
@export var uniform_scale : float = 1.0

func _init():
	meta_node = {
		"title" : "Bounds Modifier",
		"category" : "Point Ops",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Modifies the size/bounds property on points in the provided point data.",
	}

func exposeParam( name : String ) -> bool:
	if name == "padding":
		return mode == eMode.AddPadding
	if name == "bounds_min" or name == "bounds_max":
		return mode != eMode.AddPadding
	return true
	
func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
		
	var out_data : FlowData.Data = in_data.duplicate()
	var ssizes = out_data.cloneStream(FlowData.AttrSize)
	var spos = out_data.cloneStream(FlowData.AttrPosition)
	var srot = out_data.findStream(FlowData.AttrRotation)
	if spos == null or ssizes == null or srot == null:
		return
	var eulers = srot.container
	
	var b_min : Vector3 = bounds_min
	var b_max : Vector3 = bounds_max
	var size_val := ( b_max - b_min ) * 0.5
	var center := ( b_max + b_min ) * 0.25
	
	match mode:
		eMode.Set:
			var final_size := size_val * uniform_scale
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				ssizes[i] = final_size
				spos[i] += center * basis
		
		eMode.Add:
			var final_size := size_val * uniform_scale
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				ssizes[i] += final_size
				spos[i] += center * basis
		
		eMode.Multiply:
			size_val *= 0.5 * uniform_scale
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				var offset_center : Vector3 = ssizes[i] * size_val
				spos[i] += offset_center * basis
				ssizes[i] *= ( b_max + b_min ) * 0.5
		
		eMode.AddPadding:
			size_val = ( padding ) * uniform_scale
			for i in ssizes.size():
				ssizes[i] += size_val 
			
	out_data.registerStream(FlowData.AttrPosition, spos, FlowData.DataType.Vector)
	out_data.registerStream(FlowData.AttrSize, ssizes, FlowData.DataType.Vector)
	setOutput(ctx, 0, out_data)
