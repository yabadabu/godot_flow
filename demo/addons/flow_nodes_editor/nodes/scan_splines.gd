@tool
extends FlowBaseScanNode

func _init():
	meta_node = {
		"title" : "Scan Splines",
		"category" : "Spatial",
		"scans_scene" : true,
		"ins" : [],
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.NodePath }],
		"tooltip" : "Returns all splines found in the scene matching the search criteria.\nThe splines can then be sampled using the Sample Spline node.",
	}
	
func onSceneChanged( ctx : FlowData.EvaluationContext ):
	markDirty(ctx)
	
func execute( ctx : FlowData.EvaluationContext ):
	var nodes = findNodesMatchingFilters( ctx, "Path3D")
	var output := FlowData.Data.new()
	output.registerStream( "node", nodes, FlowData.DataType.NodePath )
	var curves = nodes.map( func( obj ): return obj.curve )
	output.registerStream( "curve", curves, FlowData.DataType.Resource )
	importCommon( ctx, output, nodes )
	setOutput(ctx, 0, output )
