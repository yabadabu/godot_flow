@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Transform",
		"settings" : TransformNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	var spos : PackedVector3Array = out_data.cloneStream( FlowData.AttrPosition )
	var srot : PackedVector3Array = out_data.cloneStream( FlowData.AttrRotation )
	var ssizes : PackedVector3Array = out_data.cloneStream( FlowData.AttrSize )
	var offset_min : Vector3 = settings.offset_min
	var offset_max : Vector3 = settings.offset_max
	var rotation_min : Vector3 = settings.rotation_min
	var rotation_max : Vector3 = settings.rotation_max
	var scale_min : Vector3 = settings.scale_min
	var scale_max : Vector3 = settings.scale_max
	var uniform_scale : bool = settings.uniform_scale
	for i in spos.size():
		var amount_pos = Vector3( rng.randf(), rng.randf(), rng.randf() )
		var basis := FlowData.eulerToBasis( srot[i] )
		spos[i] += basis * (offset_min + ( offset_max - offset_min ) * amount_pos)
		var amount_rot = Vector3( rng.randf(), rng.randf(), rng.randf() )
		srot[i] += rotation_min + ( rotation_max - rotation_min ) * amount_rot
		if uniform_scale:
			var amount_scale = rng.randf()
			ssizes[i] *= scale_min.x + ( scale_max.x - scale_min.x ) * amount_scale
		else:
			var amount_scale = Vector3( rng.randf(), rng.randf(), rng.randf() )
			ssizes[i] *= scale_min + ( scale_max - scale_min ) * amount_scale
	set_output( 0, out_data )
