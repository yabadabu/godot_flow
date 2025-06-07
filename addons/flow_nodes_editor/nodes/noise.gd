@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Noise",
		"settings" : NoiseNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Outputs an attribute with Noise values",
	}

func execute( ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	
	var sout : PackedFloat32Array = out_data.addStream( FlowData.DataType.Float, settings.out_attribute_name )
	if sout == null:
		return
		
	var ipos : PackedVector3Array = out_data.getContainerChecked( "position", FlowData.DataType.Vector )
	if ipos == null:
		return
		
	var noise := FastNoiseLite.new()
	noise.seed = settings.random_seed
	
	var scale : float = settings.scale
	
	for i in sout.size():
		var pos := ipos[i] * scale
		sout[i] = noise.get_noise_3d( pos.x, pos.y, pos.z )
		
	set_output( 0, out_data )
