@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Math ",
		"settings" : MathOpNodeSettings,
		"ins" : [{"label": "In A" }, {"label": "In B" }], 
		"outs" : [{ "label" : "Out" }],
	}
	
func getTitle() -> String:
	return MathOpNodeSettings.eOperation.keys()[settings.operation]

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	
	var sA = in_data.findStream( settings.in_nameA )
	var sB = in_data.findStream( settings.in_nameB )
	
	if sA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
		
	if sB == null:
		setError( "Input B %s not found" % [settings.in_nameA])
		return
	
	if sA.data_type != sB.data_type:
		setError( "Input A and B have different data types (%s vs %s)" % [sA.data_type, sB.data_type])
		return

	if sA.data_type == FlowData.DataType.Float:
		var inA : PackedFloat32Array = sA.container
		var inB : PackedFloat32Array = sB.container
		var spos : PackedFloat32Array = out_data.addStream( settings.out_name, sA.data_type )
		if spos == null:
			setError( "Invalid out name %s" % [ settings.out_name ] )
			return
		match settings.operation:
			MathOpNodeSettings.eOperation.Multiply:
				for i in spos.size():
					spos[i] = inA[i] * inB[i]
			MathOpNodeSettings.eOperation.Add:
				for i in spos.size():
					spos[i] = inA[i] + inB[i]
			MathOpNodeSettings.eOperation.Substract:
				for i in spos.size():
					spos[i] = inA[i] - inB[i]
			MathOpNodeSettings.eOperation.Divide:
				for i in spos.size():
					spos[i] = inA[i] / inB[i]
			MathOpNodeSettings.eOperation.Negate:
				for i in spos.size():
					spos[i] = -inA[i]
			MathOpNodeSettings.eOperation.Absolute:
				for i in spos.size():
					spos[i] = absf(inA[i])

	set_output( 0, out_data )
