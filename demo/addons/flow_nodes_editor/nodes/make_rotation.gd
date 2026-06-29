@tool
extends FlowNodeBase

var inZ = { "label": "Z", "multiple_connections" : false }
var inY = { "label": "Y", "multiple_connections" : false }
var inAxis = { "label": "Axis", "multiple_connections" : false }
var inAngle = { "label": "Angle", "multiple_connections" : false }

func _init():
	meta_node = {
		"title" : "Make Rotation",
		"settings" : MakeRotationNodeSettings,
		"category" : "Math",
		"ins" : [ inZ ], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a single Rotation value",
		#"trace" : true
	}
	
func getMeta() -> Dictionary:
	if settings:
		if settings.operation == MakeRotationNodeSettings.eOperation.From_Z:
			if meta_node.ins.size() != 1 or meta_node.ins[0] != inZ:
				meta_node.ins = [ inZ ]
				initFromScript()
		elif settings.operation == MakeRotationNodeSettings.eOperation.From_Z_And_Y:
			if meta_node.ins.size() != 2 or meta_node.ins[0] != inZ:
				meta_node.ins = [ inZ, inY ]
				initFromScript()
		elif settings.operation == MakeRotationNodeSettings.eOperation.From_Axis_And_Angle:
			if meta_node.ins.size() != 2 or meta_node.ins[0] != inAxis:
				meta_node.ins = [ inAxis, inAngle ]
				initFromScript()
	return meta_node

func get_input_container( in_idx : int ):
	var in_data: FlowData.Data = get_input( in_idx )
	if not in_data:
		setError( "Input %s has no data" % getMeta().ins[ in_idx ].label )
		return null
	return in_data

func get_data_type_name( data_type : FlowData.DataType ):
	return FlowData.DataType.keys()[ data_type ]

func get_typed_stream_container( in_idx : int, stream_name : StringName, data_type : FlowData.DataType, expected_size : int ):
	var in_data: FlowData.Data = get_input( in_idx )
	if not in_data:
		if stream_name.is_valid_float():
			var v : float = stream_name.to_float()
			return newFloatStream( expected_size, "Constant %s" % stream_name, v )
		else:
			setError( "Input %s has no data" % getMeta().ins[ in_idx ].label )
		return null
	var s = in_data.findStream( stream_name )
	if s == null:
		setError( "Attribute %s not found" % [stream_name])
		return null
	if s.data_type != data_type:
		setError( "Attribute %s data type should be %s but it's %s" % [stream_name, get_data_type_name( data_type ), get_data_type_name( s.data_type )])
		return null
	var s_size = s.container.size()
	if s_size != expected_size && s_size == 1 && expected_size > 0:
		if data_type == FlowData.DataType.Float:
			var v : float = s.container[0]
			s = newFloatStream( expected_size, "Constant %s" % stream_name, v )
	return s
		
func execute( ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = get_input_container( 0 )
	if not in_dataA:
		return

	var first_arg_name : String
	var second_arg_name : String
	var second_data_type : FlowData.DataType
	if settings.operation == MakeRotationNodeSettings.eOperation.From_Z:
		first_arg_name = settings.attribute_z
	elif settings.operation == MakeRotationNodeSettings.eOperation.From_Z_And_Y:
		first_arg_name = settings.attribute_z
		second_arg_name = settings.attribute_y
		second_data_type = FlowData.DataType.Vector
	elif settings.operation == MakeRotationNodeSettings.eOperation.From_Axis_And_Angle:
		first_arg_name = settings.axis
		second_arg_name = settings.angle
		second_data_type = FlowData.DataType.Float
		
	# All 3 require the arg to be an axis
	var num_elems := in_dataA.size()
	var sA = get_typed_stream_container( 0, first_arg_name, FlowData.DataType.Vector, num_elems )
	if sA == null:
		return
	var inA : PackedVector3Array = sA.container

	var outC := PackedVector3Array()
	outC.resize( num_elems )
	var out_data : FlowData.Data = in_dataA.duplicate()

	if settings.operation == MakeRotationNodeSettings.eOperation.From_Z:
		var axis_y : Vector3 = settings.axis_y
		for i in num_elems:
			outC[i] = Basis.looking_at( inA[i], axis_y ).get_euler() * 180.0 / PI

	else:
		var sB = get_typed_stream_container( 1, second_arg_name, second_data_type, num_elems )
		if sB == null:
			return
		
		match settings.operation:
			MakeRotationNodeSettings.eOperation.From_Z_And_Y:
				var inB : PackedVector3Array = sB.container
				for i in num_elems:
					outC[i] = Basis.looking_at( inA[i], inB[i] ).get_euler() * rad_to_deg( 1.0 )
				
			MakeRotationNodeSettings.eOperation.From_Axis_And_Angle:
				var inB : PackedFloat32Array = sB.container
				for i in num_elems:
					outC[i] = Quaternion( inA[i].normalized(), deg_to_rad( inB[i] ) ).get_euler() * rad_to_deg( 1.0 )
	
	var err = out_data.registerStream( settings.out_name, outC )
	if err:
		setError( err )
		return
	out_data.markStreamAsRotation( settings.out_name )
	set_output( 0, out_data )
