@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Make Transform",
		"settings" : MakeTransformNodeSettings,
		"category" : "Math",
		"ins" : [ { "label" : "Translation" }, { "label" : "Rotation" },  { "label" : "Scale" } ], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a Transform value",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_dataT : FlowData.Data = get_optional_input( 0 )
	var in_dataR : FlowData.Data = get_optional_input( 1 )
	var in_dataS : FlowData.Data = get_optional_input( 2 )
	
	var sz_T = in_dataT.size() if in_dataT else 0
	var sz_R = in_dataR.size() if in_dataR else 0
	var sz_S = in_dataS.size() if in_dataS else 0
	var num_elems : int = maxi( sz_T, maxi( sz_R, sz_S ))
	
	print( "num_elems %d/%d/%d" % [ sz_T, sz_R, sz_S ])
	if num_elems == 0:
		return
		
	var cte_T := Vector3.ZERO
	var cte_R := Vector3.ZERO
	var cte_S := Vector3.ONE
		
	var in_data : FlowData.Data
	if num_elems == 1:
		if sz_T == 1:
			var stream_T = in_dataT.findStream( settings.attribute_position )
			cte_T = stream_T.container[0]
			in_data = in_dataT
		if sz_R == 1:
			var stream_R = in_dataR.findStream( settings.attribute_rotation )
			cte_R = stream_R.container[0]
			in_data = in_dataR
		if sz_S == 1:
			var stream_S = in_dataS.findStream( settings.attribute_scale )
			cte_S = stream_S.container[0]
			in_data = in_dataS

	else:
		setError( "num_elems > 1 not yet supported ")
		return
		
	var out_data : FlowData.Data = in_data.duplicate()
		
	var outT := PackedVector3Array()
	var outR := PackedVector3Array()
	var outS := PackedVector3Array()
	outT.resize( num_elems )
	outR.resize( num_elems )
	outS.resize( num_elems )
	for i in range( num_elems ):
		outT[i] = cte_T
		outR[i] = cte_R
		outS[i] = cte_S
	
	var out_stem_name : String = settings.out_name
	var prefix : String = out_stem_name
	if prefix:
		#var err = out_data.registerStream( out_stem_name, PackedByteArray() )
		prefix += ( "." )
	var out_name_T := prefix + FlowData.AttrPosition
	var out_name_R := prefix + FlowData.AttrRotation
	var out_name_S := prefix + FlowData.AttrSize
	
	var err = out_data.registerStream( out_name_T, outT )
	if err:
		setError( err )
		return
		
	err = out_data.registerStream( out_name_R, outR )
	if err:
		setError( err )
		return
	out_data.markStreamAsRotation( out_name_R )
	
	err = out_data.registerStream( out_name_S, outS )
	if err:
		setError( err )
		return
	
	out_data.last_added_stream_name = out_stem_name
	set_output( 0, out_data )
