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

func uniformSampling( ctx : FlowData.EvaluationContext, in_trs : FlowData.TransformsStream, output : FlowData.Data ):
		
	var max_samples_x : int = getSettingValue( ctx, "max_x" )
	var max_samples_y : int = getSettingValue( ctx, "max_y" )
	var max_samples_z : int = getSettingValue( ctx, "max_z" )
	var new_size_factor : float = getSettingValue( ctx, "new_size_factor")
	var sampling_distance : float = getSettingValue( ctx, "sampling_distance")

	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )

	var num_points : int = in_trs.size()
	for i in num_points:
		var in_size := in_trs.sizes[ i ]
		
		var nx : int = in_size.x / sampling_distance
		var ny : int = in_size.y / sampling_distance
		var nz : int = in_size.z / sampling_distance
		
		nx = mini( nx, max_samples_x )
		ny = mini( ny, max_samples_y )
		nz = mini( nz, max_samples_z )
		
		var nsamples : int = nx * ny * nz
		
		var idx := spos.size()
		var new_size := idx + nsamples
		spos.resize( new_size )
		srot.resize( new_size )
		ssize.resize( new_size )

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
	

func uniformDistributedSample1D( n : int, base : float) -> float:
	const g := 1.6180339887498948482
	const a1 : float = 1.0 / g
	var v : float = (base + a1 * n)
	return v - floor(v);
	
# The seed is the base, which should be a number between 0 and 1
# the n is a seq number, starting at zero.
func uniformDistributedSample2D( n : int, base: float) -> Vector2:
	const g := 1.32471795724474602596
	const a1 := 1.0 / g
	const a2 := 1.0 / (g * g)
	var t := Vector2(base + a1 * n, base + a2 * n)
	t.x = t.x - floor(t.x)
	t.y = t.y - floor(t.y)
	return t

func uniformDistributedSample2Das3D( n : int, base: float) -> Vector3:
	var p := uniformDistributedSample2D( n, base )
	return Vector3( p.x, 0, p.y )
	
func uniformDistributedSample3D( n : int, base : float) -> Vector3:
	var q = uniformDistributedSample2D( n, base )
	return Vector3(q.x, rng.randf(), q.y)

func quasiRandomSampling( ctx : FlowData.EvaluationContext, in_trs : FlowData.TransformsStream, output : FlowData.Data ):
	
	var samplerFn : Callable= uniformDistributedSample2Das3D if settings.distribution == SamplePointsNodeSettings.eDistribution.QuasiRandom2D else uniformDistributedSample3D
	
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	var phase : float = getSettingValue( ctx, "phase" )
	var new_size_factor : Vector3 = Vector3.ONE * getSettingValue( ctx, "new_size_factor")
	
	if settings.groups.size() < 1:
		setError( "Define number of points in the group array")
		return
		
	var save_group_id : bool = true if settings.out_group_id else false
	var out_group_container := PackedInt32Array()
	if save_group_id:
		out_group_container = output.addStream( settings.out_group_id, FlowData.DataType.Int )

	var num_samples := 0
	for val : int in settings.groups:
		num_samples += val
		
	if num_samples < 0:
		num_samples = 0
	
	for i in in_trs.size():
		
		# Alloc num_samples
		var idx := spos.size()
		var new_size := idx + num_samples
		spos.resize( new_size )
		srot.resize( new_size )
		ssize.resize( new_size )
		if save_group_id:
			out_group_container.resize( new_size )
		
		var origin : Vector3 = in_trs.positions[ i ]
		var rotation : Vector3 = in_trs.eulers[ i ] 
		var size : Vector3 = in_trs.sizes[i]
		var transform = Transform3D( FlowData.eulerToBasis(rotation), origin )
		
		var offset := -size * 0.5
		if settings.distribution == SamplePointsNodeSettings.eDistribution.QuasiRandom2D:
			offset.y = 0.0
			
		var color_idx := 0
		var max_j : int = settings.groups[color_idx]
	
		for j in num_samples:
			var p : Vector3 = samplerFn.call( j, phase ) * size + offset
			spos[idx] = transform * p
			srot[idx] = rotation
			ssize[idx] = new_size_factor
			if save_group_id:
				out_group_container[idx] = color_idx
			if j >= max_j:
				max_j += settings.groups[ color_idx ]
				color_idx += 1 
			idx += 1

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var in_trs : FlowData.TransformsStream = in_data.getTransformsStream()
	if in_trs == null:
		setError( "Input does not provide position, rotation or scale streams" )
		return

	var out_data := FlowData.Data.new()
	out_data.addCommonStreams( 0 )

	if settings.distribution == SamplePointsNodeSettings.eDistribution.UniformGrid:
		uniformSampling( ctx, in_trs, out_data )
	else:
		quasiRandomSampling( ctx, in_trs, out_data )
		
	set_output( 0, out_data )
