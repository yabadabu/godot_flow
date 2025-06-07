@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Grid",
		"settings" : GridNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generates a set of points in a grid spatial distribution,\nwhere the separation is step",
	}

func execute( ):
	var output = []
	for iz in range( 0, settings.z ):
		for iy in range( 0, settings.y ):
			for ix in range( 0, settings.x ):
				var p = Vector3( ix, iy, iz ) * settings.step
				output.append(p)
	set_output( 0, output )
