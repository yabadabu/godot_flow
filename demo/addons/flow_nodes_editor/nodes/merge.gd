@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Merge",
		"settings" : MergeNodeSettings,
		"ins" : [{ "label": "In A" }, { "label": "In B" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( ctx : FlowData.EvaluationContext ):
	
	var in_dataA : FlowData.Data = get_input(0)
	var in_dataB : FlowData.Data = get_input(1)
	var in_datas = [ in_dataA, in_dataB ]

	var total_points := 0
	for in_data in in_datas:
		total_points += in_data.size()

	var out_data : FlowData.Data.new()
	var offset = 0
	for in_data in in_datas:

		# For each stream
		for stream in in_data.streams:

			# if not found in out_data, 
			var out_stream = out_data.findStream( stream.name )
			if not out_stream:
				# clone or crete or duplicate with the current size 'offset'
				pass

			# else, if data_type matches...
			elif stream.data_type != out_data.streams[ stream_name ].data_type:
				continue

			# copy elements of stream in target stream at the end
			out_stream.container.append_array( stream.container )
			pass

		offset += in_data.size()

	set_output( 0, out_data )
