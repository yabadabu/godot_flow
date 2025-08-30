@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Meshes",
		"settings" : ScanMeshesNodeSettings,
		"scans_scene" : true,
		"ins" : [],
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.NodeMesh }],
	}
	
func execute( ctx : FlowData.EvaluationContext ):
	var nodes = findNodesMatchingFilters( ctx, "MeshInstance3D")
	var output := FlowData.Data.new()
	output.registerStream( "node", nodes, FlowData.DataType.NodeMesh )
	var resources = nodes.map( func( obj ): return obj.mesh )
	output.registerStream( "mesh", resources, FlowData.DataType.Resource )
	set_output( 0, output )
