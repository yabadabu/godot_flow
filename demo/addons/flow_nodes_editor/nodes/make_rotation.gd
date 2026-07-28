@tool
extends FlowNodeBase

enum eOperation {
	From_Z,
	From_Z_And_Y,
	From_Axis_And_Angle,
	#FromEulerAngles
}

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true

@export var operation : eOperation = eOperation.From_Z:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()

@export var attribute_z : String = "@last"
@export var attribute_y : String = "@last"
@export var axis_y : Vector3 = Vector3.UP
@export var axis : String = "@last"
@export var angle : String = "@last"
@export var out_name : String = "NewRotation"

var inZ = { "label": "Z", "multiple_connections" : false }
var inY = { "label": "Y", "multiple_connections" : false }
var inAxis = { "label": "Axis", "multiple_connections" : false }
var inAngle = { "label": "Angle", "multiple_connections" : false }

func _init():
	meta_node = {
		"title" : "Make Rotation",
		"category" : "Math",
		"ins" : [ inZ ], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a single Rotation value",
		#"trace" : true
	}

func exposeParam( name : String ) -> bool:
	var arg_from_z = name == "axis_y" or name == "attribute_z"
	var arg_from_z_and_y = name == "attribute_y" or name == "attribute_z"
	var arg_from_axis_and_angle = name == "axis" or name == "angle"
	if name == "operation" or name == "out_name":
		return true
	if arg_from_z or arg_from_z_and_y or arg_from_axis_and_angle:
		if operation == eOperation.From_Z:
			return arg_from_z
		elif operation == eOperation.From_Z_And_Y:
			return arg_from_z_and_y
		elif operation == eOperation.From_Axis_And_Angle:
			return arg_from_axis_and_angle
	return true

func getMeta() -> Dictionary:
	if operation == eOperation.From_Z:
		if meta_node.ins.size() != 1 or meta_node.ins[0] != inZ:
			meta_node.ins = [ inZ ]
			connections_changed.emit()
	elif operation == eOperation.From_Z_And_Y:
		if meta_node.ins.size() != 2 or meta_node.ins[0] != inZ:
			meta_node.ins = [ inZ, inY ]
			connections_changed.emit()
	elif operation == eOperation.From_Axis_And_Angle:
		if meta_node.ins.size() != 2 or meta_node.ins[0] != inAxis:
			meta_node.ins = [ inAxis, inAngle ]
			connections_changed.emit()
	return meta_node

func getInputContainer(ctx: FlowData.EvaluationContext, in_idx: int):
	var in_data: FlowData.Data = getInput(ctx,  in_idx )
	if not in_data:
		setError(ctx,  "Input %s has no data" % getMeta().ins[ in_idx ].label )
		return null
	return in_data

func get_data_type_name( data_type : FlowData.DataType ):
	return FlowData.DataType.keys()[ data_type ]

func getTypedStreamContainer(ctx: FlowData.EvaluationContext, in_idx: int, stream_name: StringName, data_type: FlowData.DataType, expected_size: int):
	var in_data: FlowData.Data = getInput(ctx,  in_idx )
	if not in_data:
		if stream_name.is_valid_float():
			var v : float = stream_name.to_float()
			return newFloatStream( expected_size, "Constant %s" % stream_name, v )
		else:
			setError(ctx,  "Input %s has no data" % getMeta().ins[ in_idx ].label )
		return null
	var s = in_data.findStream( stream_name )
	if s == null:
		setError(ctx,  "Attribute %s not found" % [stream_name])
		return null
	if s.data_type != data_type:
		setError(ctx,  "Attribute %s data type should be %s but it's %s" % [stream_name, get_data_type_name( data_type ), get_data_type_name( s.data_type )])
		return null
	var s_size = s.container.size()
	if s_size != expected_size && s_size == 1 && expected_size > 0:
		if data_type == FlowData.DataType.Float:
			var v : float = s.container[0]
			s = newFloatStream( expected_size, "Constant %s" % stream_name, v )
	return s
		
func execute( ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = getInputContainer(ctx, 0)
	if not in_dataA:
		return

	var first_arg_name : String
	var second_arg_name : String
	var second_data_type : FlowData.DataType
	if operation == eOperation.From_Z:
		first_arg_name = attribute_z
	elif operation == eOperation.From_Z_And_Y:
		first_arg_name = attribute_z
		second_arg_name = attribute_y
		second_data_type = FlowData.DataType.Vector
	elif operation == eOperation.From_Axis_And_Angle:
		first_arg_name = axis
		second_arg_name = angle
		second_data_type = FlowData.DataType.Float
		
	# All 3 require the arg to be an axis
	var num_elems := in_dataA.size()
	var sA = getTypedStreamContainer(ctx, 0, first_arg_name, FlowData.DataType.Vector, num_elems)
	if sA == null:
		return
	var inA : PackedVector3Array = sA.container

	var outC := PackedVector3Array()
	outC.resize( num_elems )
	var out_data : FlowData.Data = in_dataA.duplicate()

	if operation == eOperation.From_Z:
		var axis_y : Vector3 = axis_y
		for i in num_elems:
			outC[i] = Basis.looking_at( inA[i], axis_y ).get_euler() * 180.0 / PI

	else:
		var sB = getTypedStreamContainer(ctx, 1, second_arg_name, second_data_type, num_elems)
		if sB == null:
			return
		
		match operation:
			eOperation.From_Z_And_Y:
				var inB : PackedVector3Array = sB.container
				for i in num_elems:
					outC[i] = Basis.looking_at( inA[i], inB[i] ).get_euler() * rad_to_deg( 1.0 )
				
			eOperation.From_Axis_And_Angle:
				var inB : PackedFloat32Array = sB.container
				for i in num_elems:
					outC[i] = Quaternion( inA[i].normalized(), deg_to_rad( inB[i] ) ).get_euler() * rad_to_deg( 1.0 )
	
	var err = out_data.registerStream( out_name, outC )
	if err:
		setError(ctx,  err )
		return
	out_data.markStreamAsRotation( out_name )
	setOutput(ctx, 0, out_data )
