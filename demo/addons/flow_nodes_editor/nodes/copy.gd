@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Copy",
		"settings" : CopyNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data := FlowData.Data.new()
	
	var num_copies : int = getSettingValue( ctx, "num_copies" )
	print( "Copy.num_copies %d" % [ num_copies ] )

	var time_start = Time.get_ticks_usec()	
	# First create all the containers with the correct type
	for stream_name in in_data.streams:
		var istream = in_data.streams[ stream_name ]
		var container = out_data.newContainerOfType( istream.data_type )
		#print( "Copy.Registering stream %s of data type %s . container %s" % [ stream_name, istream.data_type, container ] )
		out_data.registerStream( stream_name, container )

	# Then duplicate the data N times
	for stream_name in in_data.streams:
		var ocontainer = out_data.streams[ stream_name ].container
		var icontainer = in_data.streams[ stream_name ].container
		for n in range( num_copies ):
			ocontainer.append_array( icontainer )

	# Transform data of each copy
	var isize := in_data.size()
	var in_trs := in_data.getTransformsStream()
	print( "Copy.Setup: %f (%d)" % [ Time.get_ticks_usec() - time_start, isize ] )
	
	if in_trs:
		var step3d : Transform3D = Transform3D.IDENTITY
		var step_translation = getSettingValue( ctx, "translation" )
		var step_rotation = getSettingValue( ctx, "rotation" )
		step3d.origin = step_translation
		step3d.basis = FlowData.eulerToBasis( step_rotation )
		#print( "Step3d is %s" % [ step3d ] )
		
		var spos := out_data.getVector3Container( FlowData.AttrPosition )
		var srot := out_data.getVector3Container( FlowData.AttrRotation )
		var ssize := out_data.getVector3Container( FlowData.AttrSize )

		var acc_transforms : Array[ Transform3D ]
		var delta : Transform3D = Transform3D.IDENTITY
		for j in range( isize ):
			acc_transforms.push_back( delta )
			delta = delta * step3d
		
		var time_start_trs = Time.get_ticks_usec()
		# For each point...
		for j in range( isize ):
			var itrans : = in_trs.atIndex(j)
			# For each copy
			for n in range( num_copies ):
				var base := n * isize
				var otrans : Transform3D = acc_transforms[ n ] * itrans
				spos[ base + j ] = otrans.origin
				srot[ base + j ] = otrans.basis.get_euler() * 180.0 / PI	# FlowData.basisToEuler( otrans.basis )
		print( "Copy.Transform: %f" % [ Time.get_ticks_usec() - time_start_trs ] )
			
	if settings.generate_copy_id:
		var time_start_id = Time.get_ticks_usec()
		var container = PackedInt32Array()
		container.resize( num_copies * isize )
		for n in range( num_copies ):
			var base := n * isize
			for j in range( isize ):
				container[base+j] = n
		out_data.registerStream( settings.generate_copy_id, container )
		print( "Copy.GenerateId: %f" % [ Time.get_ticks_usec() - time_start_id ] )

	set_output( 0, out_data )
