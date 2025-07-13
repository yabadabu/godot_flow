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

func isSingleArgument( ) -> bool:
	return settings.operation == MathOpNodeSettings.eOperation.Absolute or \
	   settings.operation == MathOpNodeSettings.eOperation.Floor or \
	   settings.operation == MathOpNodeSettings.eOperation.Negate or \
	   settings.operation == MathOpNodeSettings.eOperation.Saturate or \
	   false

func execute( _ctx : FlowData.EvaluationContext ):
	
	var is_single_arg = isSingleArgument()
		
	if not settings.out_name:
		setError( "Output name can't be empty")
		return
	
	# Check A
	var in_dataA: FlowData.Data = get_input(0)
	var sA = in_dataA.findStream( settings.in_nameA )
	if sA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
	var num_elemsA := in_dataA.size()
	
	# B is optional, can be replaced by a cte
	var in_dataB = get_optional_input(1)
	var num_elemsB := num_elemsA
	var sB = null
	if in_dataB:
		num_elemsB = in_dataB.size()
		sB = in_dataB.findStream( settings.in_nameB )
		
	# if B is not connected, we might have a constant
	if sB == null:
		# Check if the name looks like a float
		if settings.in_nameB.is_valid_float():
			var v = settings.in_nameB.to_float()
			sB = newFloatStream( in_dataA.size(), "Constant %s" % settings.in_nameB, v )
		else:
			if not is_single_arg:
				setError( "Input B %s not found, and can't be interpreted as a constant number" % [settings.in_nameB])
				return

	# The number of elements should match, unless the B channel has just 1 element
	# in which case we will expand it. Wwe might need in the future A to be just one 
	# element and B having lots of elements, or the type not to be float...
	if num_elemsA != num_elemsB:
		if num_elemsB == 1 and num_elemsA > 0 and sB.data_type == FlowData.DataType.Float:
			sB = newFloatStream( num_elemsA, sA.name + " as float", sB.container[0])
		else:
			setError( "Num elements from A nd B do not match (%d vs %d)" % [num_elemsA, num_elemsB])
			return
	var num_elems := num_elemsA
	
	var out_data_type
	var out_container
	var out_data : FlowData.Data = in_dataA.duplicate()
	
	if sA.data_type == FlowData.DataType.Int and (is_single_arg or sB.data_type == FlowData.DataType.Float):
		sA = newFloatStream( num_elemsA, sA.name + " as float", func( idx : int ) -> float: return sA.container[idx] )
		
	if is_single_arg:
		if sA.data_type == FlowData.DataType.Float:
			var inA : PackedFloat32Array = sA.container
			var outC := PackedFloat32Array()
			outC.resize( num_elems )
			match settings.operation:
				MathOpNodeSettings.eOperation.Negate:
					for i in num_elems:
						outC[i] = -inA[i]
				MathOpNodeSettings.eOperation.Absolute:
					for i in num_elems:
						outC[i] = absf(inA[i])
				MathOpNodeSettings.eOperation.Saturate:
					for i in num_elems:
						outC[i] = clampf(inA[i], 0.0, 1.0)
				MathOpNodeSettings.eOperation.Floor:
					for i in num_elems:
						outC[i] = floorf(inA[i])
			out_container = outC
			out_data_type = FlowData.DataType.Float
		
		elif sA.data_type == FlowData.DataType.Vector:
			var inA : PackedVector3Array = sA.container
			var outC := PackedVector3Array()
			outC.resize( num_elems )
			
			match settings.operation:
				MathOpNodeSettings.eOperation.Negate:
					for i in num_elems:
						outC[i] = -inA[i]
				MathOpNodeSettings.eOperation.Absolute:
					for i in num_elems:
						outC[i].x = absf(inA[i].x)
						outC[i].y = absf(inA[i].y)
						outC[i].z = absf(inA[i].z)
				MathOpNodeSettings.eOperation.Saturate:
					for i in num_elems:
						outC[i].x = clampf(inA[i].x, 0.0, 1.0)
						outC[i].y = clampf(inA[i].y, 0.0, 1.0)
						outC[i].z = clampf(inA[i].z, 0.0, 1.0)
			out_container = outC
			out_data_type = FlowData.DataType.Vector
			
		else:
			setError( "Input A has incompatible/unsupported data types (%s vs %s)" % [sA.data_type])
			return
			
	else:
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
			setError( "Input A and B have incompatible/unsupported data types (%s vs %s)" % [sA.data_type, sB.data_type])
			return
		
	# This will override the existing stream if exists or update a substream
	var err = out_data.registerStream( settings.out_name, out_data_type, out_container )
	if err:
		setError( err )
		return
		
	set_output( 0, out_data )
