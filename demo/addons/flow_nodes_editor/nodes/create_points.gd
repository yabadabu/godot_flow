@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Create Points",
		"settings" : CreatePointsNodeSettings,
		"category" : "Spatial",
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates a set of points with custom values." 
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var num_points : int = settings.positions.size()
	output.addCommonStreams( num_points )
	var spos : PackedVector3Array = output.findStream( FlowData.AttrPosition ).container
	var srot : PackedVector3Array = output.findStream( FlowData.AttrRotation ).container
	var sszs : PackedVector3Array = output.findStream( FlowData.AttrSize ).container
	
	for i in range(num_points):
		spos[i] = settings.positions[i]
		if i < settings.rotations.size():
			srot[i] = settings.rotations[i]
		if i < settings.sizes.size():
			sszs[i] = settings.sizes[i]
	set_output( 0, output )	
