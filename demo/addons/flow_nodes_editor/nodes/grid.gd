@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Grid",
		"settings" : GridNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates a set of points in a grid spatial distribution,\nwhere the separation is step",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var nx : int = getSettingValue( ctx, "x" )
	var ny : int = getSettingValue( ctx, "y" )
	var nz : int = getSettingValue( ctx, "z" )
	var nsamples : int = nx * ny * nz
	output.addCommonStreams( nsamples )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	assert( spos != null )
	#print( "Spos.size %d of type %s" % [ spos.size(), type_string(typeof(spos)) ])
	var idx := 0
	var origin : Vector3 = getSettingValue( ctx, "origin" )
	var rotation : Vector3 = getSettingValue( ctx, "rotation" )
	var step : Vector3 = getSettingValue( ctx, "step" )
	var transform = Transform3D( FlowData.eulerToBasis(rotation), origin )
	for iz in range( 0, nz ):
		for iy in range( 0, ny ):
			for ix in range( 0, nx ):
				var p := Vector3( ix, iy, iz ) * step
				spos[idx] = transform * p
				srot[idx] = rotation
				idx += 1
	set_output( 0, output )
