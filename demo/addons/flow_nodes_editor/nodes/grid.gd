@tool
extends FlowNodeBase

@export_range( 0, 50 ) var x : int = 3
@export_range( 0, 50 ) var y : int = 1
@export_range( 0, 50 ) var z : int = 3
@export var step : Vector3 = Vector3( 1.0, 1.0, 1.0 )
@export var origin : Vector3 = Vector3.ZERO
@export var rotation : Vector3 = Vector3.ZERO
@export var size : float = 1.0

func _init():
	meta_node = {
		"title" : "Grid",
		"category" : "Spatial",
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates a set of points in a grid spatial distribution,\nwhere the separation is step",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var nx : int = x
	var ny : int = y
	var nz : int = z
	var nsamples : int = nx * ny * nz
	output.addCommonStreams( nsamples )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	assert( spos != null )
	if trace:
		print( "Grid.size %d x %d x %d" % [ nx, ny, nz ])
	var idx := 0
	var size3 : Vector3 = Vector3.ONE * size
	var transform = Transform3D( FlowData.eulerToBasis(rotation), origin )
	for iz in range( 0, nz ):
		for iy in range( 0, ny ):
			for ix in range( 0, nx ):
				var p := Vector3( ix, iy, iz ) * step
				spos[idx] = transform * p
				srot[idx] = rotation
				ssize[idx] = size3
				idx += 1
	setOutput(ctx, 0, output )
