@tool
extends FlowNodeBase

enum eOperation {
	ByDistance,
	ByNumClusters
}

@export var operation : eOperation = eOperation.ByDistance:
	set(value):
		if operation != value:
			operation = value
			notify_property_list_changed()

@export var max_distance : float = 0.1
@export var num_clusters : int = 4
@export var out_name : String = "cluster_index"
@export var in_nameA : String = FlowData.AttrPosition

func _init():
	meta_node = {
		"title" : "Clusterize",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }, { "label" : "Centroids" }],
		"tooltip" :"Creates clusters based of a maximum distance",
	}
	
func exposeParam( name : String ) -> bool:
	if name == "max_distance":
		return operation == eOperation.ByDistance
	elif name == "num_clusters":
		return operation == eOperation.ByNumClusters
	return true	
	
func execute( ctx : FlowData.EvaluationContext ):
	
	if not out_name:
		setError(ctx,  "Output name can't be empty")
		return
		
	var in_dataA : FlowData.Data = getInput(ctx, 0)
	if not in_dataA.hasStreamOfType( in_nameA, FlowData.DataType.Vector ):
		setError(ctx,  "Input A %s not found" % [in_nameA])
		return
		
	var sA := in_dataA.getVector3Container( in_nameA )
	var size_A = in_dataA.size()

	var indices : PackedInt32Array
	var centroids : PackedVector3Array
	var counts : PackedInt32Array
	
	if operation == eOperation.ByDistance:
		var kdtree = GDKdTree.new()
		kdtree.set_points( sA )
		indices = kdtree.cluster_by_distance( max_distance )

		# The cluster_by_distance does not return the centroids/counts
		for in_index in range( indices.size() ):
			var cluster_index = indices[ in_index ]
			if cluster_index >= counts.size():
				counts.resize( cluster_index + 1 )
				centroids.resize( cluster_index + 1 )
			counts[ cluster_index ] += 1
			centroids[ cluster_index ] += sA[ in_index ]
		var num_clusters_found = counts.size()
		for index in num_clusters_found:
			centroids[ index ] /= counts[ index ]

	else:
		var ans = GDStreamUtils.KMeans( sA, num_clusters, 25, 0.01, random_seed)
		if ans.result:
			indices = ans.labels
			centroids = ans.centroids
			
			# The KMeans does not provide the counts
			for cluster_index in indices:
				if cluster_index >= counts.size():
					counts.resize( cluster_index + 1 )
				counts[ cluster_index ] += 1

	var out_data : FlowData.Data = in_dataA.duplicate()
	out_data.registerStream( out_name, indices )
	setOutput(ctx, 0, out_data )

	var out_centroids := FlowData.Data.new()
	out_centroids.addCommonStreams( centroids.size() )
	out_centroids.registerStream( FlowData.AttrPosition, centroids )
	out_centroids.registerStream( "num_samples", counts )
	setOutput(ctx, 1, out_centroids )
	
