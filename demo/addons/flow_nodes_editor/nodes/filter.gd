@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Filter",
		"settings" : FilterNodeSettings,
		"category" : "Filter",
		"ins" : [{ "label": "In A" }, { "label": "In B" }, { "label": "In C" }], 
		"outs" : [{ "label" : "True" }, { "label" : "False" }],
		"hide_inputs" : true,
		"tooltip" : "Filter inputs based on some condition.\nThis node returns splits the input stream in two substreams.",
	}

func getNumArgsRequired():
	if settings.condition == FilterNodeSettings.eCondition.IsNull:
		return 1
	if settings.isBetweenCondition():
		return 3
	return 2
	
func camel_to_words(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?<=[a-z0-9])([A-Z])")
	return regex.sub(text, " $1", true)
	
func getTitle() -> String:
	return camel_to_words(FilterNodeSettings.eCondition.keys()[settings.condition])	
	
func refreshFromSettings():
	var curr_num_args = meta_node.ins.size()
	var required_num_args = getNumArgsRequired()
	if curr_num_args != required_num_args:
		match required_num_args:
			1: meta_node.ins = [{ "label": "In A" }]
			2: meta_node.ins = [{ "label": "In A" }, { "label": "In B" }]
			3: meta_node.ins = [{ "label": "In A" }, { "label": "In B" }, { "label": "In C" }]
		initFromScript()
	super.refreshFromSettings()
	
func getOptionalStream( input_index : int, stream_name : String, expected_size : int ):
	# B is optional, can be replaced by a cte
	var in_data = get_optional_input(input_index)
	var read_stream = in_data.findStream( stream_name ) if in_data else null

	if settings.trace:
		if in_data:
			print( "getOptionalStream(%d,%s,%d) is connected" % [input_index, stream_name, expected_size ])
		else:
			print( "getOptionalStream(%d,%s,%d) Not connected" % [input_index, stream_name, expected_size ])

	# if it is not connected, we might have a constant
	if read_stream == null:
		# Check if the name looks like a float
		if stream_name.is_valid_float():
			var v = stream_name.to_float()
			if settings.trace:
				print( "  Using cte with value %s. Creating a stream of %d" % [v, expected_size])
			read_stream = newFloatStream( expected_size, "Constant %s" % stream_name, v )
		elif stream_name.to_lower() == "true":
			read_stream = newFloatStream( expected_size, "Constant %s" % stream_name, 1.0 )
		else:
			setError( "Input %s not found, and can't be interpreted as a constant number (Op:%d)" % [stream_name, settings.condition])
			return	null
			
	if read_stream:
		# The number of elements should match, unless the B channel has just 1 element
		# in which case we will expand it. Wwe might need in the future A to be just one 
		# element and B having lots of elements, or the type not to be float...
		var num_elems : int = read_stream.container.size()
		if settings.trace:
			print( "  instream[%d] has size %d, (vs expected %d)" % [ input_index, num_elems, expected_size ])
		if num_elems != expected_size:
			if num_elems == 1 and expected_size > 0 and (read_stream.data_type == FlowData.DataType.Float or read_stream.data_type == FlowData.DataType.Int):
				if settings.trace:
					print( "  Converting cte to stream with value %f" % read_stream.container[0] )
				read_stream = newFloatStream( expected_size, stream_name + " as float", read_stream.container[0])
			else:
				setError( "Num elements from A and stream %s do not match (%d vs %d) vs %s" % [stream_name, expected_size, num_elems, read_stream.data_type == FlowData.DataType.Float])
				return	null
	return read_stream
	
func execute( ctx : FlowData.EvaluationContext ):
	#print( "filter.input: ", inputs )
	var in_dataA : FlowData.Data = get_input(0)
	if in_dataA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
	var sA = in_dataA.findStream( settings.in_nameA )
	if sA == null:
		setError( "Input A stream %s not found" % [settings.in_nameA])
		return
		
	var num_elemsA := in_dataA.size()
	
	var required_num_args = getNumArgsRequired()
	var requires_two_operands = required_num_args > 1
	var requires_three_operands = required_num_args > 2
	
	var sB = getOptionalStream( 1, settings.in_nameB, num_elemsA ) if requires_two_operands else null
	var sC = getOptionalStream( 2, settings.in_nameC, num_elemsA ) if requires_three_operands else null

	if err:
		return

	var num_elemsB : int = sB.size() if sB else 0
	var num_elemsC : int = sC.size() if sC else 0
	var num_elems := num_elemsA
	
	# When comparing int vs floats, promote the ints to float to reduce the casuistics
	if requires_two_operands and sA.data_type == FlowData.DataType.Int and sB.data_type == FlowData.DataType.Float:
		sA = newFloatStream( num_elemsA, sA.name + " as float", func( idx : int ) -> float: return sA.container[idx] )
		
	# Also, when comparing bools vs floats, promote the bool to float to reduce the casuistics
	if requires_two_operands and sA.data_type == FlowData.DataType.Bool and sB.data_type == FlowData.DataType.Float:
		sA = newFloatStream( num_elemsA, sA.name + " as float", func( idx : int ) -> float: return sA.container[idx] )

	# This will store the indices that pass the test
	var indices_true = PackedInt32Array( )
	var indices_false = PackedInt32Array( )
		
	if requires_two_operands and sA.data_type == FlowData.DataType.Float and sB.data_type == FlowData.DataType.Float and not requires_three_operands:
		var inA : PackedFloat32Array = sA.container
		var inB : PackedFloat32Array = sB.container
		match settings.condition:

			FilterNodeSettings.eCondition.Equal:
				for i in range(num_elems):
					if inA[i] == inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.NotEqual:
				for i in num_elems:
					if inA[i] != inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.Greater:
				for i in num_elems:
					if inA[i] > inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.GreaterOrEqual:
				for i in num_elems:
					if inA[i] >= inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.Less:
				for i in num_elems:
					if inA[i] < inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.LessOrEqual:
				for i in num_elems:
					if inA[i] <= inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.AlmostEqual:
				var threshold : float = getSettingValue( ctx, "threshold" )
				for i in num_elems:
					if abs(inA[i] - inB[i]) < threshold:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.LogicalAND:
				for i in num_elems:
					if inA[i] && inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.LogicalOR:
				for i in num_elems:
					if inA[i] || inB[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.LogicalXOR:
				for i in num_elems:
					if bool(inA[i]) != bool(inB[i]):
						indices_true.append(i)
					else:
						indices_false.append(i)

			FilterNodeSettings.eCondition.IsNull:
				for i in num_elems:
					if !inA[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
						
	elif requires_three_operands:
		var inA : PackedFloat32Array = sA.container
		var inB : PackedFloat32Array = sB.container
		var inC : PackedFloat32Array = sC.container 
		match settings.condition:
			FilterNodeSettings.eCondition.BetweenExcludingMinMax:
				for i in num_elems:
					if inA[i] > inB[i] && inA[i] < inC[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
			FilterNodeSettings.eCondition.BetweenIncludingMinMax:
				for i in num_elems:
					if inA[i] >= inB[i] && inA[i] <= inC[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
			FilterNodeSettings.eCondition.BetweenIncludingMin:
				for i in num_elems:
					if inA[i] >= inB[i] && inA[i] < inC[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
			FilterNodeSettings.eCondition.BetweenIncludingMax:
				for i in num_elems:
					if inA[i] > inB[i] && inA[i] <= inC[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
						
	elif not requires_two_operands and not requires_three_operands:
		var inA = sA.container
		match settings.condition:
			FilterNodeSettings.eCondition.IsNull:
				for i in num_elems:
					if !inA[i]:
						indices_true.append(i)
					else:
						indices_false.append(i)
	else:
		setError( "Input A and B must have int/float type" )
		return

	var out_data_true = in_dataA.filter( indices_true )
	var out_data_false = in_dataA.filter( indices_false )
	set_output( 0, out_data_true )
	set_output( 1, out_data_false )
