@tool
extends FlowNodeBase

enum eOperation {
	Transform_Location,
	Transform_Direction,
}

@export var attribute_transform : String = "@last"

@export var operation : eOperation = eOperation.Transform_Location:
	set(value):
		if operation != value:
			operation = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
func _init():
	meta_node = {
		"title" : "Transform Op",
		"category" : "Math",
		"ins" : [{ "label": "In" }, {"label": "Transform"}], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Applies the transform to each point",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	# Check if we have something to transform
	if not in_data:
		setOutput(ctx, 0, FlowData.Data.new() )
		return
		
	var trs_to_apply : FlowData.Data = getInput(ctx, 1)
	if not trs_to_apply:
		setOutput(ctx, 0, FlowData.Data.new() )
		return
		
	# Input data TRS
	var in_trs := trs_to_apply.getTransformsStream( attribute_transform )
	if not in_trs:
		setOutput(ctx, 0, FlowData.Data.new() )
		return
		
	var in_size = in_data.size()
	var out_data : FlowData.Data = in_data.duplicate()
	
	# Generate a new spos stream only if we are going to move the points
	var spos : PackedVector3Array
	if operation == eOperation.Transform_Location:
		spos = out_data.cloneStream( FlowData.AttrPosition )
	var srot : PackedVector3Array = out_data.cloneStream( FlowData.AttrRotation )

	if in_trs.size() == 1:
		var basis := Basis.from_euler( in_trs.eulers[0] * deg_to_rad(1) )
		var t := Transform3D( basis, in_trs.positions[0] ).scaled_local( in_trs.sizes[0] )
		for i in range( in_size ):
			if spos:
				spos[i] = t * spos[i]
			var basis_i := Basis.from_euler( srot[i] * deg_to_rad(1) )
			srot[i] = (basis * basis_i).get_euler() * rad_to_deg(1)
	else:
		for i in range( in_size ):
			var basis := Basis.from_euler( in_trs.eulers[i] * deg_to_rad(1) )
			if spos:
				var t := Transform3D( basis, in_trs.positions[i] ).scaled_local( in_trs.sizes[i] )
				spos[i] = t * spos[i]
			var basis_i := Basis.from_euler( srot[i] * deg_to_rad(1) )
			srot[i] = (basis * basis_i).get_euler() * rad_to_deg(1)
	
	setOutput(ctx, 0, out_data )
