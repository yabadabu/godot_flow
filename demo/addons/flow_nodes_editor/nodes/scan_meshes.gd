@tool
extends FlowBaseScanNode

func _init():
	meta_node = {
		"title" : "Scan Meshes",
		"category" : "Spatial",
		"scans_scene" : true,
		"ins" : [],
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.NodeMesh }],
		"tooltip" : "Returns all MeshInstance3D nodes found in the scene matching the search criteria.",
	}
	
func execute( ctx : FlowData.EvaluationContext ):
	var nodes = findNodesMatchingFilters( ctx, "MeshInstance3D")
	var output := FlowData.Data.new()
	output.registerStream( "node", nodes, FlowData.DataType.NodeMesh )
	var resources = nodes.map( func( obj ): return obj.mesh )
	output.registerStream( "mesh", resources, FlowData.DataType.Resource )
	importCommon( ctx, output, nodes )
	setOutput(ctx, 0, output )
