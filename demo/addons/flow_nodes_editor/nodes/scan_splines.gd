@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Splines",
		"settings" : ScanSplinesNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out", "type" : TYPE_NODE_PATH }],
	}
	
func execute( ctx : FlowData.EvaluationContext ):
	var nodes = findNodesMatchingFilters( ctx, "Path3D")
	var output := FlowData.Data.new()
	output.registerStream( "node", nodes, FlowData.DataType.Node )
	var curves = nodes.map( func( obj ): return obj.curve )
	output.registerStream( "curve", curves, FlowData.DataType.Resource )
	set_output( 0, output )
