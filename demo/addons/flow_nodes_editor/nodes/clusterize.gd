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
		"outs" : [{ "label" : "Out" }],
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

	var out_data : FlowData.Data = in_dataA.duplicate()
	
	if operation == eOperation.ByDistance:
		var kdtree = GDKdTree.new()
		kdtree.set_points( sA )
		var indices : PackedInt32Array = kdtree.cluster_by_distance( max_distance )
		out_data.registerStream( out_name, indices )
	else:
		var ans = GDStreamUtils.KMeans( sA, num_clusters, 25, 0.01, random_seed)
		if ans.result:
			out_data.registerStream( out_name, ans.labels )

	setOutput(ctx, 0, out_data )
