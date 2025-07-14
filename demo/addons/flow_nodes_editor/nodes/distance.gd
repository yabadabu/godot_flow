@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Distance",
		"settings" : DistanceNodeSettings,
		"ins" : [{"label": "In" }, {"label": "Target" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( ctx : FlowData.EvaluationContext ):
	
	if not settings.out_name:
		setError( "Output name can't be empty")
		return
		
	var in_dataA : FlowData.Data = get_input(0)
	var sA := in_dataA.getVector3Container( settings.in_nameA )
	if sA == null:
		setError( "Input A %s not found" % [settings.in_nameA])
		return
		
	var in_dataB : FlowData.Data = get_input(1)
	var sB := in_dataB.getVector3Container( settings.in_nameB )
	if sB == null:
		setError( "Input B %s not found" % [settings.in_nameB])
		return
		
	var size_A = in_dataA.size()
		
	var kdtree = GDKdTree.new()
	kdtree.set_points( sB )
	print( "Populated kdtree with %d points. WIll check %d" % [in_dataB.size(), size_A])
	#var nearest_indices : PackedInt32Array = kdtree.find_nearest_indices( sA )
	
	var inv_max_distance : float = 1.0 / settings.max_distance if settings.max_distance > 0 else 1.0
	
	var out_data : FlowData.Data = in_dataA.duplicate()
	var out_container := PackedFloat32Array()
	out_container.resize( size_A )
	for idx in range(size_A):
		var idxB := kdtree.find_nearest_idx( sA[ idx ] )
		var delta := sA[ idx ] - sB[ idxB ]
		out_container[ idx ] = delta.length() * inv_max_distance
	
	var err = out_data.registerStream( settings.out_name, out_container )
	set_output( 0, out_data )
