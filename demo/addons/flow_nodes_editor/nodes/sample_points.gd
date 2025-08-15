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
	return v - int(v);
	
# The seed is the base, which should be a number between 0 and 1
# the n is a seq number, starting at zero.
func uniformDistributedSample2D( n : int, base: float) -> Vector2:
	var g := 1.32471795724474602596
	var a1 := 1.0 / g
	var a2 := 1.0 / (g * g)
	var t := Vector2(base + a1 * n, base + a2 * n)
	t.x = t.x - int(t.x)
	t.y = t.y - int(t.y)
	return t

#VEC3 uniformDistributedSample3D(int n, float base) {
#float g = 1.2207440846057594736f;
#float a1 = 1.0f / g;
#float a2 = 1.0f / (g * g);
#float a3 = 1.0f / (g * g * g);
#VEC3 t = VEC3(base + a1 * n, base + a2 * n, base + a3 * n);
#t.x = t.x - (int)t.x;
#t.y = t.y - (int)t.y;
#t.z = t.z - (int)t.z;
#return t;
#}

	
func quasiRandomSampling( ctx : FlowData.EvaluationContext, in_trs : FlowData.TransformsStream, output : FlowData.Data ):
	
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	var num_samples : int = getSettingValue( ctx, "num_points" )
	var phase : float = getSettingValue( ctx, "phase" )
	var new_size_factor : Vector3 = Vector3.ONE * getSettingValue( ctx, "new_size_factor")
	for i in in_trs.size():
		
		# Alloc num_samples
		var idx := spos.size()
		var new_size := idx + num_samples
		spos.resize( new_size )
		srot.resize( new_size )
		ssize.resize( new_size )
		
		var origin : Vector3 = in_trs.positions[ i ]
		var rotation : Vector3 = in_trs.eulers[ i ] 
		var size : Vector3 = in_trs.sizes[i]
		var transform = Transform3D( FlowData.eulerToBasis(rotation), origin )
		
		for j in num_samples:
			var coords := uniformDistributedSample2D( j, phase )
			var p := Vector3( coords.x - 0.5, 0.0, coords.y  - 0.5 ) * size
			spos[idx] = transform * p
			srot[idx] = rotation
			ssize[idx] = new_size_factor
			idx += 1

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var in_trs : FlowData.TransformsStream = in_data.getTransformsStream()
	if in_trs == null:
		setError( "Input does not provide position, rotation or scale streams" )
		return

	var out_data := FlowData.Data.new()
	out_data.addCommonStreams( 0 )

	if getSettingValue( ctx, "uniform_sampling" ):
		uniformSampling( ctx, in_trs, out_data )
	else:
		quasiRandomSampling( ctx, in_trs, out_data )
		
	set_output( 0, out_data )
