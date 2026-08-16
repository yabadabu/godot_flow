@tool
extends FlowNodeBase

@export var max_distance : float = 0.1

func _init():
	meta_node = {
		"title" : "Collapse Points",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Fuses points too near between each one",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	
	var sA := in_data.getVector3Container( FlowData.AttrPosition )
	var size = in_data.size()
	var kdtree = GDKdTree.new()
	kdtree.set_points( sA )
	
	var processed := PackedByteArray()
	processed.resize( sA.size() )
	
	var filtered := PackedInt32Array()
	var res = kdtree.find_nearest_indices( sA )
	#print( "Res size %d" % res.size() )
	#var out_data = in_data.duplicate()
	#out_data.registerStream( "nearest_idx", res, FlowData.DataType.Int )
	#var out_distances = PackedFloat32Array()
	#out_distances.resize( size )
	var threshold_sqr = max_distance * max_distance
	for idx in res.size():
		if processed[idx]:
			continue
			
		# We have computed the nearest vertex. Use it to quickly discard points which 
		# are too far from other points
		var d_sqr = (sA[idx] - sA[ res[idx] ]).length_squared()
		if d_sqr < threshold_sqr: 
			var near_indices : PackedInt32Array = kdtree.find_points_near(sA[idx], max_distance)
			for other_index in near_indices:
				processed[ other_index ] = 1
		processed[ idx ] = 1
		filtered.append( idx )

	var out_data = in_data.filter( filtered )
	setOutput(ctx, 0, out_data )
