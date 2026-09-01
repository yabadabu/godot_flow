@tool
extends FlowNodeBase

enum eOperation {
	Add,
	Substract,
	Multiply,
	Divide,
	Negate,			# 4
	Absolute,
	Saturate,
	Floor,
	FloorAsInt,
	Modulo,
	ModuloInt,
	Frac,
	Max,
	Min,
	OneMinus,
	Pow,
	Round,
	Sign,
	Sqrt,
	Set,
}

@export var operation : eOperation = eOperation.Add:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
@export var in_nameA : String = "@last"
@export var in_nameB : String = "@last"
@export var out_name : String = "@source"

var inA = { "label": "In A", "multiple_connections" : false }
var inB = {
	"label": "In B",
	"multiple_connections": false,
	"optional": true,
}

func _init():
	meta_node = {
		"title" : "Math",
		"category" : "Math",
		"ins" : [inA, inB], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Applies a math operation between two streams, storing the result in a new stream or overriding another.\nYou can read and write substreams like position.X",
		"keywords" : [ "multiply", "add", "negate" ],
	}
	
func isSingleArgument( ) -> bool:
	return operation == eOperation.Absolute or \
	   operation == eOperation.Floor or \
	   operation == eOperation.FloorAsInt or \
	   operation == eOperation.Negate or \
	   operation == eOperation.Saturate or \
	   operation == eOperation.OneMinus or \
	   operation == eOperation.Sign or \
	   operation == eOperation.Sqrt or \
	   false

func exposeParam( name : String ) -> bool:
	if name == "in_nameB":
		return not isSingleArgument()
	return true	
	
func getMeta() -> Dictionary:
	var curr_num_args = meta_node.ins.size()
	var required_num_args = 1 if isSingleArgument() else 2
	if curr_num_args != required_num_args:
		match required_num_args:
			1: meta_node.ins = [inA]
			2: meta_node.ins = [inA, inB]
		connections_changed.emit()
	return meta_node
		
func getTitle() -> String:
	if title != "Math" and title:
		return title
	return eOperation.keys()[operation]	

func execute( ctx : FlowData.EvaluationContext ):
	var time_start_init = Time.get_ticks_usec()	
	
	var is_single_arg = isSingleArgument()
		
	if not out_name:
		setError(ctx,  "Output name can't be empty")
		return
	var final_out_name = out_name
	if final_out_name == "@source":
		final_out_name = in_nameA
	
	# Check A
	var in_dataA: FlowData.Data = getInput(ctx, 0)
	var sA = in_dataA.findStream( in_nameA )
	if sA == null:
		setError(ctx,  "Input A %s not found" % [in_nameA])
		return
	var num_elemsA := in_dataA.size()
	
	# B is optional, can be replaced by a cte
	var in_dataB = getOptionalInput(ctx, 1)
	var num_elemsB := num_elemsA
	var sB = null
	if in_dataB:
		num_elemsB = in_dataB.size()
		sB = in_dataB.findStream( in_nameB )
		
	# if B is not connected, we might have a constant
	if sB == null:
		# Check if the name looks like a float
		if in_nameB.is_valid_float():
			var v = in_nameB.to_float()
			sB = newFloatStream( in_dataA.size(), "Constant %s" % in_nameB, v )
		else:
			if not is_single_arg:
				setError(ctx,  "Input B %s not found, and can't be interpreted as a constant number. #Inputs:%d" % [in_nameB, getInputCount(ctx)])
				return

	# The number of elements should match, unless the B channel has just 1 element
	# in which case we will expand it. Wwe might need in the future A to be just one 
	# element and B having lots of elements, or the type not to be float...
	if num_elemsA != num_elemsB:
		if num_elemsB == 1 and num_elemsA > 0:
			if sB.data_type == FlowData.DataType.Float:
				sB = newFloatStream( num_elemsA, sA.name + " as float", sB.container[0])
			elif sB.data_type == FlowData.DataType.Vector:
				sB = newStream( num_elemsA, sA.name + " as vector3", sB.container[0], FlowData.DataType.Vector )
			elif sB.data_type == FlowData.DataType.Color:
				sB = newStream( num_elemsA, sA.name + " as color", sB.container[0], FlowData.DataType.Color )
			else:
				setError(ctx,  "Num elements from A nd B do not match (%d vs %d). But In B data type must be a float, Vector3, or Color" % [num_elemsA, num_elemsB])
				return
		else:
			setError(ctx,  "Num elements from A nd B do not match (%d vs %d)" % [num_elemsA, num_elemsB])
			return
	var num_elems := num_elemsA
	
	var out_container
	var out_data : FlowData.Data = in_dataA.duplicate()
	
	if trace: print( "Math.init: %f (%d)" % [ Time.get_ticks_usec() - time_start_init, num_elems ] )
	
	if sA.data_type == FlowData.DataType.Int and (is_single_arg or sB.data_type == FlowData.DataType.Float):
		sA = newFloatStream( num_elemsA, sA.name + " as float", func( idx : int ) -> float: return sA.container[idx] )
		
	if is_single_arg:

		if sA.data_type == FlowData.DataType.Float:
			var inA : PackedFloat32Array = sA.container
			
			if operation == eOperation.FloorAsInt:
				var outI := PackedInt32Array()
				outI.resize( num_elems )
				for i in num_elems:
					outI[i] = floori(inA[i])
				out_container = outI
				
			else:
				var outC := PackedFloat32Array()
				outC.resize( num_elems )
				match operation:
					eOperation.Negate:
						for i in num_elems:
							outC[i] = -inA[i]
					eOperation.Absolute:
						for i in num_elems:
							outC[i] = absf(inA[i])
					eOperation.Saturate:
						for i in num_elems:
							outC[i] = clampf(inA[i], 0.0, 1.0)
					eOperation.Floor:
						for i in num_elems:
							outC[i] = floorf(inA[i])
					eOperation.Round:
						for i in num_elems:
							outC[i] = roundf(inA[i])
					eOperation.OneMinus:
						for i in num_elems:
							outC[i] = 1.0 - inA[i]
					eOperation.Sign:
						for i in num_elems:
							outC[i] = -1 if inA[i] < 0 else ( 1.0 if inA[i] > 0 else 0)
					eOperation.Sqrt:
						for i in num_elems:
							outC[i] = sqrt( max( 0.0, inA[i] ) )
					_:
						setError(ctx,  "Scalar single arg op %s not yet supported" % eOperation.keys()[ operation ]  )
				out_container = outC
		
		elif sA.data_type == FlowData.DataType.Vector:
			var inA : PackedVector3Array = sA.container
			var outC := PackedVector3Array()
			outC.resize( num_elems )
			
			match operation:
				eOperation.Negate:
					for i in num_elems:
						outC[i] = -inA[i]
				eOperation.Absolute:
					for i in num_elems:
						outC[i].x = absf(inA[i].x)
						outC[i].y = absf(inA[i].y)
						outC[i].z = absf(inA[i].z)
				eOperation.Saturate:
					for i in num_elems:
						outC[i].x = clampf(inA[i].x, 0.0, 1.0)
						outC[i].y = clampf(inA[i].y, 0.0, 1.0)
						outC[i].z = clampf(inA[i].z, 0.0, 1.0)
				_:
					setError(ctx,  "Vector single arg op %s not yet supported" % eOperation.keys()[ operation ]  )
			out_container = outC
			
		else:
			setError(ctx,  "Input A has incompatible/unsupported data types (%s vs %s)" % [sA.data_type])
			return
			
	else:
		if sA.data_type == FlowData.DataType.Float and sB.data_type == FlowData.DataType.Float:
			var time_start = Time.get_ticks_usec()

			var inA : PackedFloat32Array = sA.container
			
			var inB : PackedFloat32Array = sB.container
			var outC := PackedFloat32Array()
			outC.resize( num_elems )
			out_container = outC
			
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = inA[i] * inB[i]
				eOperation.Add:
					for i in num_elems:
						outC[i] = inA[i] + inB[i]
				eOperation.Substract:
					for i in num_elems:
						outC[i] = inA[i] - inB[i]
				eOperation.Divide:
					for i in num_elems:
						outC[i] = inA[i] / inB[i]
				eOperation.Modulo:
					for i in num_elems:
						outC[i] = fmod(inA[i], inB[i])
				eOperation.Frac:
					for i in num_elems:
						outC[i] = fmod(inA[i], inB[i])
				eOperation.Min:
					for i in num_elems:
						outC[i] = minf(inA[i], inB[i])
				eOperation.Max:
					for i in num_elems:
						outC[i] = maxf(inA[i], inB[i])
				eOperation.ModuloInt:
					var outI := PackedInt32Array()
					outI.resize( num_elems )
					out_container = outI
					for i in num_elems:
						var iA := int( inA[i] + 1e-6 )
						var iB := int( inB[i] + 1e-6 )
						outI[i] = iA % iB
				eOperation.Pow:
					for i in num_elems:
						outC[i] = pow( inA[i], inB[i] )
				eOperation.Set:
					for i in num_elems:
						outC[i] = inB[i]
				_:
					setError(ctx,  "Float vs Float operation %s not supported yet" % eOperation.keys()[ operation ]  )
			if trace: print( "Math.Loop: %f (%d)" % [ Time.get_ticks_usec() - time_start, num_elems ] )
			
		elif sA.data_type == FlowData.DataType.Vector && sB.data_type == FlowData.DataType.Vector:
			var inA : PackedVector3Array = sA.container
			var inB : PackedVector3Array = sB.container
			var outC := PackedVector3Array()
			outC.resize( num_elems )
			
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = inA[i] * inB[i]
				eOperation.Add:
					for i in num_elems:
						outC[i] = inA[i] + inB[i]
				eOperation.Substract:
					for i in num_elems:
						outC[i] = inA[i] - inB[i]
				eOperation.Divide:
					for i in num_elems:
						outC[i] = inA[i] / inB[i]
				eOperation.Set:
					for i in num_elems:
						outC[i] = inB[i]
				_:
					setError(ctx,  "Vector3 vs Vector3 operation not supported yet")
			out_container = outC

		elif sA.data_type == FlowData.DataType.Vector && sB.data_type == FlowData.DataType.Float:
			var inA : PackedVector3Array = sA.container
			var inB : PackedFloat32Array = sB.container
			var outC := PackedVector3Array()
			outC.resize( num_elems )
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = inA[i] * inB[i]
				eOperation.Divide:
					for i in num_elems:
						outC[i] = inA[i] / inB[i]
				_:
					setError(ctx,  "Vector3 vs Float operation not supported yet")
			out_container = outC

		elif sA.data_type == FlowData.DataType.Color && sB.data_type == FlowData.DataType.Color:
			var inA : PackedColorArray = sA.container
			var inB : PackedColorArray = sB.container
			var outC := PackedColorArray()
			outC.resize( num_elems )
			
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = Color(inA[i].r * inB[i].r, inA[i].g * inB[i].g, inA[i].b * inB[i].b, inA[i].a * inB[i].a)
				eOperation.Add:
					for i in num_elems:
						outC[i] = Color(inA[i].r + inB[i].r, inA[i].g + inB[i].g, inA[i].b + inB[i].b, inA[i].a + inB[i].a)
				eOperation.Substract:
					for i in num_elems:
						outC[i] = Color(inA[i].r - inB[i].r, inA[i].g - inB[i].g, inA[i].b - inB[i].b, inA[i].a - inB[i].a)
				eOperation.Divide:
					for i in num_elems:
						outC[i] = Color(inA[i].r / inB[i].r, inA[i].g / inB[i].g, inA[i].b / inB[i].b, inA[i].a / inB[i].a)
				_:
					setError(ctx,  "Color vs Color operation not supported yet")
			out_container = outC

		elif sA.data_type == FlowData.DataType.Color && sB.data_type == FlowData.DataType.Float:
			var inA : PackedColorArray = sA.container
			var inB : PackedFloat32Array = sB.container
			var outC := PackedColorArray()
			outC.resize( num_elems )
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = Color(inA[i].r * inB[i], inA[i].g * inB[i], inA[i].b * inB[i], inA[i].a * inB[i])
				eOperation.Divide:
					for i in num_elems:
						outC[i] = Color(inA[i].r / inB[i], inA[i].g / inB[i], inA[i].b / inB[i], inA[i].a / inB[i])
				eOperation.Add:
					for i in num_elems:
						outC[i] = Color(inA[i].r + inB[i], inA[i].g + inB[i], inA[i].b + inB[i], inA[i].a + inB[i])
				eOperation.Substract:
					for i in num_elems:
						outC[i] = Color(inA[i].r - inB[i], inA[i].g - inB[i], inA[i].b - inB[i], inA[i].a - inB[i])
				_:
					setError(ctx,  "Color vs Float operation not supported yet")
			out_container = outC

		elif sA.data_type == FlowData.DataType.Int && sB.data_type == FlowData.DataType.Int:
			var inA : PackedInt32Array = sA.container
			var inB : PackedInt32Array = sB.container
			var outC := PackedInt32Array()
			outC.resize( num_elems )
			match operation:
				eOperation.Multiply:
					for i in num_elems:
						outC[i] = inA[i] * inB[i]
				eOperation.Add:
					for i in num_elems:
						outC[i] = inA[i] + inB[i]
				eOperation.Substract:
					for i in num_elems:
						outC[i] = inA[i] - inB[i]
				eOperation.Divide:
					for i in num_elems:
						outC[i] = inA[i] / inB[i]
				eOperation.ModuloInt:
					for i in num_elems:
						outC[i] = inA[i] % inB[i]
				eOperation.Min:
					for i in num_elems:
						outC[i] = mini( inA[i], inB[i] )
				eOperation.Max:
					for i in num_elems:
						outC[i] = maxi( inA[i], inB[i] )
				_:
					setError(ctx,  "Int vs Int operation not supported yet")
			out_container = outC
	
		else:
			setError(ctx,  "Input A and B have incompatible/unsupported data types (%s vs %s)" % [sA.data_type, sB.data_type])
			return

	var time_start_end = Time.get_ticks_usec()
	# This will override the existing stream if exists or update a substream
	var err = out_data.registerStream( final_out_name, out_container )
	if err:
		setError(ctx,  err )
		return
		
	setOutput(ctx, 0, out_data )
	if trace: print( "Math.end:  %f (%d)" % [ Time.get_ticks_usec() - time_start_end, num_elems ] )
