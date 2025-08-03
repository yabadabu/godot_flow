@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Noise",
		"settings" : NoiseNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Outputs an attribute with Noise values",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
		
	var ipos : PackedVector3Array = out_data.getContainerChecked( FlowData.AttrPosition, FlowData.DataType.Vector )
	if ipos == null:
		return
		
	var noise := FastNoiseLite.new()
	noise.seed = settings.random_seed
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_VALUE
	#noise.cellular_distance_function = FastNoiseLite.CellularDistanceFunction.DISTANCE_EUCLIDEAN
	#noise.cellular_return_type = FastNoiseLite.CellularReturnType.RETURN_DISTANCE
	
	var in_scale : float = settings.in_scale
	var noise_bias : float = settings.noise_bias
	var noise_amplitude : float = settings.noise_amplitude
	
	var in_size := in_data.size()
	var sout : PackedFloat32Array
	sout.resize( in_size )
	for i in range(in_size):
		var pos := ipos[i] * in_scale
		var raw_noise := noise.get_noise_3d( pos.x, pos.y, pos.z )
		var noise_01 = ( raw_noise + 1.0 ) * 0.5
		var nval = clampf( noise_01, 0.0, 1.0 )
		sout[i] = noise_bias + nval * noise_amplitude
	
	out_data.registerStream( settings.out_name, sout )
	
	set_output( 0, out_data )
