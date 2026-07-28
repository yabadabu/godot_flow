@tool
extends FlowNodeBase

enum eOperation {
	FromTranslationRotationScale
}
			
# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true

@export var operation : eOperation = eOperation.FromTranslationRotationScale:
	set(value):
		if operation != value:
			operation = value
			notify_property_list_changed()

@export var attribute_position : String = "@last"
@export var attribute_rotation : String = "@last"
@export var attribute_scale : String = "@last"
@export var out_name : String = "@source"

func _init():
	meta_node = {
		"title" : "Make Transform",
		"category" : "Math",
		"ins" : [
			{ "label" : "Translation", "optional": true },
			{ "label" : "Rotation", "optional": true },
			{ "label" : "Scale", "optional": true },
		], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a Transform value",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_dataT : FlowData.Data = getOptionalInput(ctx,  0 )
	var in_dataR : FlowData.Data = getOptionalInput(ctx,  1 )
	var in_dataS : FlowData.Data = getOptionalInput(ctx,  2 )
	
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
			var stream_T = in_dataT.findStream( attribute_position )
			cte_T = stream_T.container[0]
			in_data = in_dataT
		if sz_R == 1:
			var stream_R = in_dataR.findStream( attribute_rotation )
			cte_R = stream_R.container[0]
			in_data = in_dataR
		if sz_S == 1:
			var stream_S = in_dataS.findStream( attribute_scale )
			cte_S = stream_S.container[0]
			in_data = in_dataS

	else:
		setError(ctx,  "num_elems > 1 not yet supported ")
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
	
	var out_stem_name : String = out_name
	var prefix : String = out_stem_name
	if prefix:
		#var err = out_data.registerStream( out_stem_name, PackedByteArray() )
		prefix += ( "." )
	var out_name_T := prefix + FlowData.AttrPosition
	var out_name_R := prefix + FlowData.AttrRotation
	var out_name_S := prefix + FlowData.AttrSize
	
	var err = out_data.registerStream( out_name_T, outT )
	if err:
		setError(ctx,  err )
		return
		
	err = out_data.registerStream( out_name_R, outR )
	if err:
		setError(ctx,  err )
		return
	out_data.markStreamAsRotation( out_name_R )
	
	err = out_data.registerStream( out_name_S, outS )
	if err:
		setError(ctx,  err )
		return
	
	out_data.last_added_stream_name = out_stem_name
	setOutput(ctx, 0, out_data )
