@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Bounds Modifier",
		"settings" : BoundsModifierNodeSettings,
		"category" : "Point Ops",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Modifies the size/bounds property on points in the provided point data.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
		
	var out_data : FlowData.Data = in_data.duplicate()
	var ssizes = out_data.cloneStream(FlowData.AttrSize)
	var spos = out_data.cloneStream(FlowData.AttrPosition)
	var srot = out_data.findStream(FlowData.AttrRotation)
	if spos == null or ssizes == null or srot == null:
		return
	var eulers = srot.container
	var uniform_scale : float = getSettingValue( ctx, "uniform_scale", 1.0 )
	
	var b_min : Vector3 = settings.bounds_min
	var b_max : Vector3 = settings.bounds_max
	var size_val := ( b_max - b_min ) * 0.5
	var center := ( b_max + b_min ) * 0.25
	
	match settings.mode:
		BoundsModifierNodeSettings.eMode.Set:
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				ssizes[i] = size_val
				spos[i] += center * basis
		
		BoundsModifierNodeSettings.eMode.Add:
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				ssizes[i] += size_val
				spos[i] += center * basis
		
		BoundsModifierNodeSettings.eMode.Multiply:
			size_val *= 0.5
			for i in ssizes.size():
				var basis := FlowData.eulerToBasis(eulers[i]).inverse()
				var offset_center : Vector3 = ssizes[i] * size_val
				spos[i] += offset_center * basis
				ssizes[i] *= ( b_max + b_min ) * 0.5
		
		BoundsModifierNodeSettings.eMode.AddPadding:
			size_val = ( settings.padding ) * uniform_scale
			for i in ssizes.size():
				ssizes[i] += size_val 
			
	out_data.registerStream(FlowData.AttrPosition, spos, FlowData.DataType.Vector)
	out_data.registerStream(FlowData.AttrSize, ssizes, FlowData.DataType.Vector)
	set_output(0, out_data)
