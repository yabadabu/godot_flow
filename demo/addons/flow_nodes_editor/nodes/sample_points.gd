@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Sample Points",
		"settings" : SamplePointsNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Subdivides each int point into a subgrid of regular points with the specified sampling distance",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var in_trs : FlowData.TransformsStream = in_data.getTransformsStream()
	if in_trs == null:
		setError( "Input does not provide position, rotation or scale streams" )
		return
		
	var max_samples_x : int = getSettingValue( ctx, "max_x" )
	var max_samples_y : int = getSettingValue( ctx, "max_y" )
	var max_samples_z : int = getSettingValue( ctx, "max_z" )
	var new_size_factor : float = getSettingValue( ctx, "new_size_factor")

	var output := FlowData.Data.new()
	var sampling_distance : float = getSettingValue( ctx, "sampling_distance" )
	sampling_distance = maxf( sampling_distance, 0.1 )
	output.addCommonStreams( 0 )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )

	var num_points : int = in_data.size()
	for i in num_points:
		var in_size := in_trs.sizes[ i ]
		
		var nx : int = in_size.x / sampling_distance
		var ny : int = in_size.y / sampling_distance
		var nz : int = in_size.z / sampling_distance
		
		nx = mini( nx, max_samples_x )
		ny = mini( ny, max_samples_y )
		nz = mini( nz, max_samples_z )
		
		var base := spos.size()
		var nsamples : int = nx * ny * nz
		var new_size = base + nsamples
		
		spos.resize( new_size )
		srot.resize( new_size )
		ssize.resize( new_size )

		var idx := base
		var origin : Vector3 = in_trs.positions[ i ]
		var rotation : Vector3 = in_trs.eulers[ i ] 
		var step : Vector3 = Vector3.ONE * sampling_distance
		var size : Vector3 = step * new_size_factor
		var transform = Transform3D( FlowData.eulerToBasis(rotation), origin )
		var hx = nx / 2
		var hy = ny / 2
		var hz = nz / 2
		for iz in range( 0, nz ):
			for iy in range( 0, ny ):
				for ix in range( 0, nx ):
					var p := Vector3( ix - hx, iy - hy, iz - hz ) * step
					spos[idx] = transform * p
					srot[idx] = rotation
					ssize[idx] = size
					idx += 1
					
	set_output( 0, output )
