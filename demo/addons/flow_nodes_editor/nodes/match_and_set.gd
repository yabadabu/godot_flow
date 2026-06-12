@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Match And Set",
		"settings" : MatchAndSetNodeSettings,
		"category" : "Metadata",
		"ins" : [{ "label" : "In" }, { "label" : "Attributes" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Copies attributes into input data set based on a match_attr." + 
					"\nThe match_attr is used to pick an asset where the match attribute is the sample in the In and Attributes stream." + 
					"\nThe weight_attr controls if some assets should be picked more frequently than others." + 
					"\nIf none are set, a random point from the Attributes entry is picked and assigned to each In point" 
	}
	
class WeightsRandomSampler:
	var cumulative  : PackedFloat32Array
	var num_weights : int = 0
	var total_weight : float = 0.0
	func _init( in_weights : PackedFloat32Array ):
		cumulative  = PackedFloat32Array()
		num_weights = in_weights.size()
		cumulative .resize(num_weights)
		total_weight = 0.0
		for i in num_weights:
			total_weight += maxf(in_weights[i], 0.0)
			cumulative[i] = total_weight
			
	func sample( unit_val : float ) -> int:
		if total_weight <= 0.0:
			return -1
		var r := unit_val * total_weight
		var lo := 0
		var hi := cumulative.size() - 1
		while lo < hi:
			var mid := (lo + hi) / 2
			if r < cumulative[mid]:
				hi = mid
			else:
				lo = mid + 1
		return lo

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var attrs_data : FlowData.Data = get_input(1)
	if attrs_data == null || in_data == null:
		setError( "Attributes input is required" )
		return
		
	var using_lut := false
	var lut := {}
	var input_lut_container
	var match_attr : String = getSettingValue( ctx, "match_attr" )
	if match_attr:
		var match_stream = attrs_data.findStream( match_attr )
		if match_stream == null:
			setError( "Can't find attribute %s in Attributes input" % match_attr )
			return
		var input_lut_stream = in_data.findStream( match_attr )
		if input_lut_stream == null:
			setError( "Can't find attribute %s in In input" % match_attr )
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
		
	var weight_attr : String = getSettingValue( ctx, "weight_attr" )
	var weight_stream = attrs_data.findStream( weight_attr )
	if weight_attr and not weight_stream:
		setError( "Can't find weight attribute %s" % weight_attr )
		return
	if weight_attr and weight_stream and weight_stream.data_type != FlowData.DataType.Float:
		setError( "Weight attribute %s should have type float" % weight_attr )
	
	# Create the new streams
	var out_data : FlowData.Data = in_data.duplicate()
	var in_containers := []
	var out_containers := []
	for attr_stream in attrs_data.streams.values():
		var new_container = out_data.addStream( attr_stream.name, attr_stream.data_type )
		# print( "new_container: ", attr_stream, " Sz:", new_container.size())
		in_containers.append( attr_stream.container )
		out_containers.append( new_container )
	var num_new_streams := out_containers.size()		
		
	var copyPoint := func( dst_idx : int, src_idx : int ):
		for j in range(num_new_streams):
			out_containers[ j ][ dst_idx ] = in_containers[ j ][ src_idx ]
		
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
				copyPoint.call( idx, attr_idx )
			else:
				missings[ in_lut_value ] = true
				#print( "%s not found in lut Type:%s" % [ ín_lut_value, type_string(typeof( ín_lut_value )) ])
				pass

	else:
		var num_choices := attrs_data.size()
		if num_choices > 0 && num_new_streams > 0:
			
			if weight_stream:
				var sampler := WeightsRandomSampler.new( weight_stream.container )
				for idx in range( out_data.size() ):
					var attr_idx := sampler.sample( rng.randf() )
					copyPoint.call( idx, attr_idx )
				
			else:
				for idx in range( out_data.size() ):
					var attr_idx := rng.randi_range( 0, num_choices - 1 )
					# print( "Copy all attr of in_attr[%d] into out_data[%d]" % [attr_idx, idx])
					copyPoint.call( idx, attr_idx )
			
	set_output( 0, out_data )
