@tool
extends FlowNodeBase

@export_range(0.0, 1.0) var weight : float = 0.5
@export var max_distance : float = 5.0
@export var out_name = FlowData.AttrPosition

func _init():
	meta_node = {
		"title" : "Attract",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }, { "label": "Attractors" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Attracts attributes to the nearest point",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	var attractors_data : FlowData.Data = getInput(ctx, 1)
	var out_data : FlowData.Data = in_data.duplicate()
	
	# The points and the attractor positions
	var in_pos := in_data.getVector3Container( FlowData.AttrPosition )
	var attractors_pos := attractors_data.getVector3Container( FlowData.AttrPosition )
	
	# Associate to each point the nearest attractor
	var kdtree = GDKdTree.new()
	kdtree.set_points( attractors_pos )
	#print( "Populated kdtree with %d points. WIll check %d" % [in_dataB.size(), size_A])
	var nearest_indices : PackedInt32Array = kdtree.find_nearest_indices( in_pos )

	var out_container := PackedVector3Array()
	var in_size : int = in_data.size()
	out_container.resize( in_size )
	for idx in range(in_size):
		var nearest_attractor_index := nearest_indices[ idx ]
		var delta := attractors_pos[ nearest_attractor_index ] - in_pos[ idx ]
		if delta.length() < max_distance:
			out_container[ idx ] = in_pos[ idx ] + delta * weight
		else:
			out_container[ idx ] = in_pos[ idx ]
			
	out_data.registerStream( out_name, out_container )
	setOutput(ctx, 0, out_data )
		
