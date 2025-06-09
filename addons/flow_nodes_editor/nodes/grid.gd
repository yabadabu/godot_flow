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

func execute( _ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var spos : PackedVector3Array = output.addStream( "position", FlowData.DataType.Vector )
	if spos == null:
		return
	var nsamples : int = settings.x * settings.y * settings.z
	spos.resize( nsamples )
	#print( "Spos.size %d of type %s" % [ spos.size(), type_string(typeof(spos)) ])
	var idx := 0
	var step : Vector3 = settings.step
	for iz in range( 0, settings.z ):
		for iy in range( 0, settings.y ):
			for ix in range( 0, settings.x ):
				var p := Vector3( ix, iy, iz ) * step
				spos[idx] = p
				idx += 1
	set_output( 0, output )
