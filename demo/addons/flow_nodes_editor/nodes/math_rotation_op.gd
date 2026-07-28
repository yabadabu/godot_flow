@tool
extends FlowNodeBase

enum eOperation {
	Combine,
	Invert,
	Lerp,
}

@export var operation : eOperation = eOperation.Lerp:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
@export var in_nameA : String = "@last"
@export var in_nameB : String = "@last"
@export var in_nameC : String = "@last"
@export var out_name : String = "@Source"

var inA = { "label": "In A", "multiple_connections" : false }
var inB = { "label": "In B", "multiple_connections" : false }
var inC = { "label": "Weights", "multiple_connections" : false }

func _init():
	meta_node = {
		"title" : "Rotation",
		"category" : "Math",
		"ins" : [inA, inB, inC], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Applies a rotation operation between two streams, storing the result in a new stream or overriding another.\nEach involved stream will be presented in Euler Angles",
		"keywords" : [ "lerp", "invert", "compose" ],
	}

func isSingleArgument( ) -> bool:
	return operation == eOperation.Invert or \
	   false

func isTriArgument( ) -> bool:
	return operation == eOperation.Lerp or \
	   false

func exposeParam( name : String ) -> bool:
	if name == "in_nameB":
		return not isSingleArgument()
	return true
	
func getMeta() -> Dictionary:
	var curr_num_args = meta_node.ins.size()
	var required_num_args = 2
	if isSingleArgument():
		required_num_args = 1
	elif isTriArgument():
		required_num_args = 3
	if curr_num_args != required_num_args:
		match required_num_args:
			1: meta_node.ins = [inA]
			2: meta_node.ins = [inA, inB]
			3: meta_node.ins = [inA, inB, inC]
		connections_changed.emit()
	return meta_node
		
func getTitle() -> String:
	return eOperation.keys()[operation]	

func execute( ctx : FlowData.EvaluationContext ):
	if not out_name:
		setError(ctx,  "Output name can't be empty")
		return
		
	var required_num_args = getMeta().ins.size()
	
	# Check A
	var in_dataA: FlowData.Data = getInput(ctx, 0)
	if not in_dataA:
		setError(ctx,  "Input A has no data" )
		return
	var sA = in_dataA.findStream( in_nameA )
	if sA == null:
		setError(ctx,  "Input A %s not found" % [in_nameA])
		return
	if sA.data_type != FlowData.DataType.Vector:
		setError(ctx,  "Input A %s must be of type Vector" % [in_nameA])
		return
	var num_elemsA := in_dataA.size()
	
	# B is optional, can be replaced by a cte
	var in_dataB = getOptionalInput(ctx, 1)
	var num_elemsB := num_elemsA
	var sB = null
	if in_dataB:
		num_elemsB = in_dataB.size()
		sB = in_dataB.findStream( in_nameB )
		if sB and sB.data_type != FlowData.DataType.Vector:
			setError(ctx,  "Input B %s must be of type Vector" % [in_nameB])
			return
		
	# if B is not connected, we might have a constant
	if sB == null:
		if required_num_args > 1:
			setError(ctx,  "Input B %s not found. #Inputs:%d" % [in_nameB, getInputCount(ctx)])
			return

	# C is optional, can be replaced by a cte
	var in_dataC = getOptionalInput(ctx, 2)
	var num_elemsC := num_elemsA
	var sC = null
	if in_dataC:
		num_elemsC = in_dataC.size()
		sC = in_dataC.findStream( in_nameC )
		if sC and sC.data_type != FlowData.DataType.Float:
			setError(ctx,  "Input %s must be of type Float not %s" % [in_nameC, FlowData.DataType.keys()[ sC.data_type ]])
			return
		
	# if C is not connected, we might have a constant
	if sC == null:
		# Check if the name looks like a float
		if in_nameC.is_valid_float():
			var v = in_nameC.to_float()
			sC = newFloatStream( num_elemsA, "Constant %s" % in_nameC, v )
		elif required_num_args > 2:
			setError(ctx,  "Input C %s not found" % [in_nameC])
			return

	# The number of elements should match, unless the B channel has just 1 element
	# in which case we will expand it. Wwe might need in the future A to be just one 
	# element and B having lots of elements, or the type not to be float...
	if num_elemsA != num_elemsB:
		if num_elemsB == 1 and num_elemsA > 0:
			if sB.data_type != FlowData.DataType.Vector:
				sB = newStream( num_elemsA, sB.name + " as vector3", sB.container[0], FlowData.DataType.Vector )
		else:
			setError(ctx,  "Num elements from A and B do not match (%d vs %d)" % [num_elemsA, num_elemsB])
			return
			
	if num_elemsA != num_elemsC:
		if num_elemsC == 1 and num_elemsA > 0:
			# Convert the single value to an array
			sC = newFloatStream( num_elemsA, "Constant %s" % in_nameC, sC.container[0] )
		else:
			setError(ctx,  "Num elements from A and C do not match (%d vs %d)" % [num_elemsA, num_elemsC])
			return
			
			
	var num_elems := num_elemsA
	
	var outC := PackedVector3Array()
	var out_data : FlowData.Data = in_dataA.duplicate()
			
	if required_num_args == 1:
		var inA : PackedVector3Array = sA.container
		outC.resize( num_elems )
		match operation:
			eOperation.Invert:
				for i in num_elems:
					outC[i] = -inA[i]
			_:
				setError(ctx,  "Rotation single arg op %s not yet supported" % eOperation.keys()[ operation ]  )
			
	elif required_num_args == 2:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		outC.resize( num_elems )
		
		match operation:
			eOperation.Combine:
				for i in num_elems:
					var qA := Quaternion.from_euler( inA[i] * PI / 180.0 )
					var qB := Quaternion.from_euler( inB[i] * PI / 180.0 )
					var qC := qB * qA
					outC[i] = qC.get_euler() * 180 / PI
			_:
				setError(ctx,  "Rotation Vector3 vs Vector3 not supported yet")

	elif required_num_args == 3:
		var inA : PackedVector3Array = sA.container
		var inB : PackedVector3Array = sB.container
		var inC : PackedFloat32Array = sC.container
		outC.resize( num_elems )
		
		match operation:
			eOperation.Lerp:
				for i in num_elems:
					
					var qA := Quaternion.from_euler( inA[i] * PI / 180.0 )
					var qB := Quaternion.from_euler( inB[i] * PI / 180.0 )
					var qC := qA.slerp( qB, inC[i] )
					outC[i] = qC.get_euler() * 180 / PI
			_:
				setError(ctx,  "Rotation with 3 args not supported yet")

	# This will override the existing stream if exists or update a substream
	var out_name = out_name
	if out_name == "@source":
		out_name = in_nameA
	var err = out_data.registerStream( out_name, outC )
	if err:
		setError(ctx,  err )
		return
		
	out_data.markStreamAsRotation( out_name )
	setOutput(ctx, 0, out_data )
