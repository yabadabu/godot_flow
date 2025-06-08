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
	
	var sout : PackedFloat32Array = out_data.addStream( settings.out_attribute_name, FlowData.DataType.Float )
	if sout == null:
		return
		
	var ipos : PackedVector3Array = out_data.getContainerChecked( "position", FlowData.DataType.Vector )
	if ipos == null:
		return
		
	var noise := FastNoiseLite.new()
	noise.seed = settings.random_seed
	
	var in_scale : float = settings.in_scale
	var noise_bias : float = settings.noise_bias
	var noise_amplitude : float = settings.noise_amplitude
	
	for i in sout.size():
		var pos := ipos[i] * in_scale
		var raw_noise := noise.get_noise_3d( pos.x, pos.y, pos.z )
		var noise_01 = ( raw_noise + 1.0 ) * 0.5
		var nval = clampf( noise_01, 0.0, 1.0 )
		sout[i] = noise_bias + nval * noise_amplitude
		
	set_output( 0, out_data )
