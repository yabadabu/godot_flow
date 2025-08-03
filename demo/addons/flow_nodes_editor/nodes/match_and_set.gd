@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Match And Set",
		"settings" : MatchAndSetNodeSettings,
		"ins" : [{ "label" : "In" }, { "label" : "Attributes" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Copies attributes into input data set based on a weight_attr.\nCurrently there is no match operation.",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var attrs_data : FlowData.Data = get_input(1)
	if attrs_data == null || in_data == null:
		return
	
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
	var num_choices = attrs_data.size()
	if num_choices > 0 && num_new_streams > 0:
		for idx in range( out_data.size() ):
			var attr_idx = rng.randi_range( 0, num_choices - 1 )
			# print( "Copy all attr of in_attr[%d] into out_data[%d]" % [attr_idx, idx])
			for j in range(num_new_streams):
				out_containers[ j ][ idx ] = in_containers[ j ][ attr_idx ]
			
	set_output( 0, out_data )
