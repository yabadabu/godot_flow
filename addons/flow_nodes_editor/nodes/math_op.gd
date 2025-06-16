@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Math",
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
		setError( "Input B %s not found" % [settings.in_nameB])
		return
		
	if not settings.out_name:
		setError( "Output name can't be empty")
		return
	
	if sA.data_type != sB.data_type:
		setError( "Input A and B have different data types (%s vs %s)" % [sA.data_type, sB.data_type])
		return

	var out_container
	if sA.data_type == FlowData.DataType.Float:
		var inA : PackedFloat32Array = sA.container
		var inB : PackedFloat32Array = sB.container
		var num_elems := inA.size()
		var outC := PackedFloat32Array()
		outC.resize( num_elems )
		
		match settings.operation:
			MathOpNodeSettings.eOperation.Multiply:
				for i in num_elems:
					outC[i] = inA[i] * inB[i]
			MathOpNodeSettings.eOperation.Add:
				for i in num_elems:
					outC[i] = inA[i] + inB[i]
			MathOpNodeSettings.eOperation.Substract:
				for i in num_elems:
					outC[i] = inA[i] - inB[i]
			MathOpNodeSettings.eOperation.Divide:
				for i in num_elems:
					outC[i] = inA[i] / inB[i]
			MathOpNodeSettings.eOperation.Negate:
				for i in num_elems:
					outC[i] = -inA[i]
			MathOpNodeSettings.eOperation.Absolute:
				for i in num_elems:
					outC[i] = absf(inA[i])
		out_container = outC
			
	elif sA.data_type == FlowData.DataType.Vector:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		var num_elems := inA.size()
		var outC := PackedVector3Array()
		outC.resize( num_elems )
		
		match settings.operation:
			MathOpNodeSettings.eOperation.Negate:
				for i in num_elems:
					outC[i] = -inA[i]
		out_container = outC

	# This will override the existing stream if exists or update a substream
	var err = out_data.registerStream( settings.out_name, sA.data_type, out_container )
	if err:
		setError( err )
		return
		
	set_output( 0, out_data )
