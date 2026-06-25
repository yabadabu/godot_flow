@tool
extends FlowNodeBase

var inA = { "label": "In A", "multiple_connections" : false }
var inB = { "label": "In B", "multiple_connections" : false }
var inC = { "label": "Weights", "multiple_connections" : false }

func _init():
	meta_node = {
		"title" : "Rotation",
		"settings" : MathRotationOpNodeSettings,
		"category" : "Math",
		"ins" : [inA, inB, inC], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Applies a rotation operation between two streams, storing the result in a new stream or overriding another.\nEach involved stream will be presented in Euler Angles",
		"keywords" : [ "lerp", "invert", "compose" ],
	}
	
func getMeta() -> Dictionary:
	if settings:
		var curr_num_args = meta_node.ins.size()
		var required_num_args = 2
		if settings.isSingleArgument():
			required_num_args = 1
		elif settings.isTriArgument():
			required_num_args = 3
		if curr_num_args != required_num_args:
			match required_num_args:
				1: meta_node.ins = [inA]
				2: meta_node.ins = [inA, inB]
				3: meta_node.ins = [inA, inB, inC]
			initFromScript()
	return meta_node
		
func getTitle() -> String:
	return MathRotationOpNodeSettings.eOperation.keys()[settings.operation]	

func execute( _ctx : FlowData.EvaluationContext ):
	if not settings.out_name:
		setError( "Output name can't be empty")
		return
		
	var required_num_args = getMeta().ins.size()
	
	# Check A
	var in_dataA: FlowData.Data = get_input(0)
	if not in_dataA:
		setError( "Input A has no data" )
		return
	var sA = in_dataA.findStream( settings.in_nameA )
	if sA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
	if sA.data_type != FlowData.DataType.Vector:
		setError( "Input A %s must be of type Vector" % [settings.in_nameA])
		return
	var num_elemsA := in_dataA.size()
	
	# B is optional, can be replaced by a cte
	var in_dataB = get_optional_input(1)
	var num_elemsB := num_elemsA
	var sB = null
	if in_dataB:
		num_elemsB = in_dataB.size()
		sB = in_dataB.findStream( settings.in_nameB )
		if sB and sB.data_type != FlowData.DataType.Vector:
			setError( "Input B %s must be of type Vector" % [settings.in_nameB])
			return
		
	# if B is not connected, we might have a constant
	if sB == null:
		if required_num_args > 1:
			setError( "Input B %s not found" % [settings.in_nameB, inputs.size()])
			return

	# C is optional, can be replaced by a cte
	var in_dataC = get_optional_input(2)
	var num_elemsC := num_elemsA
	var sC = null
	if in_dataC:
		num_elemsC = in_dataC.size()
		sC = in_dataC.findStream( settings.in_nameC )
		if sC and sC.data_type != FlowData.DataType.Float:
			setError( "Input %s must be of type Float not %s" % [settings.in_nameC, FlowData.DataType.keys()[ sC.data_type ]])
			return
		
	# if C is not connected, we might have a constant
	if sC == null:
		# Check if the name looks like a float
		if settings.in_nameC.is_valid_float():
			var v = settings.in_nameC.to_float()
			sC = newFloatStream( num_elemsA, "Constant %s" % settings.in_nameC, v )
		elif required_num_args > 2:
			setError( "Input C %s not found" % [settings.in_nameC])
			return

	# The number of elements should match, unless the B channel has just 1 element
	# in which case we will expand it. Wwe might need in the future A to be just one 
	# element and B having lots of elements, or the type not to be float...
	if num_elemsA != num_elemsB:
		if num_elemsB == 1 and num_elemsA > 0:
			if sB.data_type != FlowData.DataType.Vector:
				sB = newStream( num_elemsA, sB.name + " as vector3", sB.container[0], FlowData.DataType.Vector )
		else:
			setError( "Num elements from A and B do not match (%d vs %d)" % [num_elemsA, num_elemsB])
			return
			
	if num_elemsA != num_elemsC:
		if num_elemsC == 1 and num_elemsA > 0:
			# Convert the single value to an array
			sC = newFloatStream( num_elemsA, "Constant %s" % settings.in_nameC, sC.container[0] )
		else:
			setError( "Num elements from A and C do not match (%d vs %d)" % [num_elemsA, num_elemsC])
			return
			
			
	var num_elems := num_elemsA
	
	var outC := PackedVector3Array()
	var out_data : FlowData.Data = in_dataA.duplicate()
			
	if required_num_args == 1:
		var inA : PackedVector3Array = sA.container
		outC.resize( num_elems )
		match settings.operation:
			MathRotationOpNodeSettings.eOperation.Invert:
				for i in num_elems:
					outC[i] = -inA[i]
			_:
				setError( "Rotation single arg op %s not yet supported" % MathRotationOpNodeSettings.eOperation.keys()[ settings.operation ]  )
			
	elif required_num_args == 2:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		outC.resize( num_elems )
		
		match settings.operation:
			MathRotationOpNodeSettings.eOperation.Combine:
				for i in num_elems:
					var qA := Quaternion.from_euler( inA[i] * PI / 180.0 )
					var qB := Quaternion.from_euler( inB[i] * PI / 180.0 )
					var qC := qB * qA
					outC[i] = qC.get_euler() * 180 / PI
			_:
				setError( "Rotation Vector3 vs Vector3 not supported yet")

	elif required_num_args == 3:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		var inC : PackedFloat32Array = sC.container
		outC.resize( num_elems )
		
		match settings.operation:
			MathRotationOpNodeSettings.eOperation.Lerp:
				for i in num_elems:
					
					var qA := Quaternion.from_euler( inA[i] * PI / 180.0 )
					var qB := Quaternion.from_euler( inB[i] * PI / 180.0 )
					var qC := qA.slerp( qB, inC[i] )
					outC[i] = qC.get_euler() * 180 / PI
			_:
				setError( "Rotation with 3 args not supported yet")

	# This will override the existing stream if exists or update a substream
	var out_name = settings.out_name
	if out_name == "@source":
		out_name = settings.in_nameA
	var err = out_data.registerStream( out_name, outC )
	if err:
		setError( err )
		return
		
	out_data.markStreamAsRotation( out_name )
	set_output( 0, out_data )
