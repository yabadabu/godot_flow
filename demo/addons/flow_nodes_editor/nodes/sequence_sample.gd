@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Sequence Sample",
		"settings" : SequenceSampleNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Samples 'count' input values from the input, starting at Start and using a 'Step' as gap.\nIf count = 0 means all points.\nNegative values mean backwards",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	
	var indices := PackedInt32Array( )
	
	var start : int = getSettingValue(ctx, "start")
	var count : int = getSettingValue(ctx, "count")
	var step : int = getSettingValue(ctx, "step")
	
	var n := in_data.size()
	if (n != 0) and (step != 0):

		var idx := start if start >= 0 else n + start

		# Determine number of iterations
		var iterations := count if count > 0 else n
		var i := 0
		while i < iterations:
			if idx < 0 or idx >= n:
				break
			indices.append(idx)
			idx += step
			i += 1
	
	var out_data = in_data.filter( indices )
	set_output( 0, out_data )
