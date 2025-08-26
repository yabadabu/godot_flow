@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Splines",
		"settings" : ScanSplinesNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out", "type" : TYPE_NODE_PATH }],
	}

func findNodesOfType(root: Node, type_name: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	
	# Check if current node matches
	if root.get_class() == type_name:
		found_nodes.append(root)
	
	var required_meta_bool = settings.get( "required_meta_bool" )
	
	# Recursively check children
	for child in root.get_children():
		if !required_meta_bool or child.get_meta(required_meta_bool, false):
			found_nodes.append_array(findNodesOfType(child, type_name))
	
	return found_nodes
	
func execute( ctx : FlowData.EvaluationContext ):
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return null
		
	var trace := settings.trace
		
	var path3d_nodes = findNodesMatchingFilters( ctx, "Path3D")

	var output := FlowData.Data.new()
	output.registerStream( "node", path3d_nodes, FlowData.DataType.Node )
	var curves = path3d_nodes.map( func( obj ): return obj.curve )
	output.registerStream( "curve", curves, FlowData.DataType.Resource )
	set_output( 0, output )
