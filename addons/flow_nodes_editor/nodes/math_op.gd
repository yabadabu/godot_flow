@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Math",
		"settings" : MathOpNodeSettings,
		"ins" : [{"label": "In A" }, {"label": "In B" }], 
		"outs" : [{ "label" : "Out" }],
	}
	
func getTitle() -> String:
	return MathOpNodeSettings.eOperation.keys()[settings.operation]

func execute( _ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = get_input(0)
	var in_dataB : FlowData.Data = get_input(1)
	var out_data : FlowData.Data = in_dataA.duplicate()
	
	var sA = in_dataA.findStream( settings.in_nameA )
	var sB = in_dataB.findStream( settings.in_nameB )
	
	if sA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
		
	if sB == null:
		setError( "Input B %s not found" % [settings.in_nameB])
		return
		
	if not settings.out_name:
		setError( "Output name can't be empty")
		return

	var num_elemsA := in_dataA.size()
	var num_elemsB := in_dataB.size()
	if num_elemsA != num_elemsB:
		setError( "Num elements from A nd B do not match (%d vs %d)" % [num_elemsA, num_elemsB])
		return
	var num_elems := num_elemsA
	
	var out_data_type
	var out_container
	if sA.data_type == FlowData.DataType.Float and sB.data_type == FlowData.DataType.Float:
		var inA : PackedFloat32Array = sA.container
		var inB : PackedFloat32Array = sB.container
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
		out_data_type = FlowData.DataType.Float
			
	elif sA.data_type == FlowData.DataType.Vector && sB.data_type == FlowData.DataType.Vector:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		var outC := PackedVector3Array()
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
					outC[i].x = absf(inA[i].x)
					outC[i].y = absf(inA[i].y)
					outC[i].z = absf(inA[i].z)
		out_container = outC
		out_data_type = FlowData.DataType.Vector

	elif sA.data_type == FlowData.DataType.Vector && sB.data_type == FlowData.DataType.Float:
		var inA : PackedVector3Array = sA.container
		var inB : PackedFloat32Array = sB.container
		var outC := PackedVector3Array()
		outC.resize( num_elems )
		match settings.operation:
			MathOpNodeSettings.eOperation.Multiply:
				for i in num_elems:
					outC[i] = inA[i] * inB[i]
			MathOpNodeSettings.eOperation.Divide:
				for i in num_elems:
					outC[i] = inA[i] / inB[i]
		out_container = outC
		out_data_type = FlowData.DataType.Vector
		
	else:
		setError( "Input A and B have incompatible data types (%s vs %s)" % [sA.data_type, sB.data_type])
		return
		
	# This will override the existing stream if exists or update a substream
	var err = out_data.registerStream( settings.out_name, out_data_type, out_container )
	if err:
		setError( err )
		return
		
	set_output( 0, out_data )
