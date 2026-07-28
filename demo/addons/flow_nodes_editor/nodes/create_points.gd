@tool
extends FlowNodeBase

@export var positions: PackedVector3Array
@export var rotations: PackedVector3Array
@export var sizes:     PackedVector3Array

func _init():
	meta_node = {
		"title" : "Create Points",
		"category" : "Spatial",
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates a set of points with custom values." 
	}

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var num_points : int = positions.size()
	output.addCommonStreams( num_points )
	var spos : PackedVector3Array = output.findStream( FlowData.AttrPosition ).container
	var srot : PackedVector3Array = output.findStream( FlowData.AttrRotation ).container
	var sszs : PackedVector3Array = output.findStream( FlowData.AttrSize ).container
	
	for i in range(num_points):
		spos[i] = positions[i]
		if i < rotations.size():
			srot[i] = rotations[i]
		if i < sizes.size():
			sszs[i] = sizes[i]
	setOutput(ctx, 0, output )
