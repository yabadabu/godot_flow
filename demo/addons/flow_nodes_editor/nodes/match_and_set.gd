@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Match And Set",
		"settings" : MatchAndSetNodeSettings,
		"ins" : [{ "label" : "In" }, { "label" : "Attributes" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Copies attributes into input data set based on a weight_attr.",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var attrs_data : FlowData.Data = get_input(1)
	if attrs_data == null || in_data == null:
		return
		
	var using_lut := false
	var lut := {}
	var input_lut_container
	if settings.weight_attr:
		var match_stream = attrs_data.findStream( settings.weight_attr )
		if match_stream == null:
			setError( "Can't find attribute %s in Attributes input" % settings.weight_attr )
			return
		var input_lut_stream = in_data.findStream( settings.weight_attr )
		if input_lut_stream == null:
			setError( "Can't find attribute %s in In input" % settings.weight_attr )
			return
		input_lut_container = input_lut_stream.container
		var attr_index := 0
		for value in match_stream.container:
			if not value in lut:
				var empty_int_array: Array[int] = []
				lut[ value ] = empty_int_array
			lut[ value ].append( attr_index )
			attr_index += 1
		using_lut = true
	
	# Create the new streams
	var out_data : FlowData.Data = in_data.duplicate()
	var in_containers = []
	var out_containers = []
	for attr_stream in attrs_data.streams.values():
		var new_container = out_data.addStream( attr_stream.name, attr_stream.data_type )
		# print( "new_container: ", attr_stream, " Sz:", new_container.size())
		in_containers.append( attr_stream.container )
		out_containers.append( new_container )
		
	var num_new_streams := out_containers.size()		
	if using_lut:
		var missings = {}
		for idx in range( out_data.size() ):
			var in_lut_value : String = str(input_lut_container[ idx ])
			if lut.has( in_lut_value ):
				var candidate_indices : Array[int] = lut[in_lut_value]
				var num_choices := candidate_indices.size()
				var choice_index := rng.randi_range( 0, num_choices - 1 )
				var attr_idx := candidate_indices[ choice_index ]
				#print( "OutPoint: %d Using attr index %d" % [ idx, attr_idx ])
				for j in range(num_new_streams):
					out_containers[ j ][ idx ] = in_containers[ j ][ attr_idx ]
			else:
				missings[ in_lut_value ] = true
				#print( "%s not found in lut Type:%s" % [ ín_lut_value, type_string(typeof( ín_lut_value )) ])
				pass

	else:
		var num_choices = attrs_data.size()
		if num_choices > 0 && num_new_streams > 0:
			for idx in range( out_data.size() ):
				var attr_idx = rng.randi_range( 0, num_choices - 1 )
				# print( "Copy all attr of in_attr[%d] into out_data[%d]" % [attr_idx, idx])
				for j in range(num_new_streams):
					out_containers[ j ][ idx ] = in_containers[ j ][ attr_idx ]
			
	set_output( 0, out_data )
