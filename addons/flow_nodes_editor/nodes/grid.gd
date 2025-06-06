@tool
extends FlowNodeBase

@export var x : int = 4
@export var y : int = 4
@export var z : int = 1
@export var step : Vector3 = Vector3( 1.0, 1.0, 1.0 )

func getMeta() -> Dictionary :
	return {
		"title" : "Grid",
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generates a set of points in a grid spatial distribution,\nwhere the separation is step"
	}

func execute( ):
	var output = []
	for iz in range( 0, z ):
		for iy in range( 0, y ):
			for ix in range( 0, x ):
				var p = Vector3( ix, iy, iz ) * step
				output.append(p)
	set_output( 0, output )
