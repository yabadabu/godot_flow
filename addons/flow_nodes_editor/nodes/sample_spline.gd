@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Sample Spline",
		"settings" : SampleSplineNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
	}
	

func findNodesOfType(root: Node, type_name: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	
	# Check if current node matches
	if root.get_class() == type_name:
		found_nodes.append(root)
	
	# Recursively check children
	for child in root.get_children():
		found_nodes.append_array(findNodesOfType(child, type_name))
	
	return found_nodes	

func execute( _ctx : FlowData.EvaluationContext ):
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return null
		
	var path3d_nodes = findNodesOfType(root, "Path3D")
	print("Found ", path3d_nodes.size(), " Path3D nodes:")

	var output := FlowData.Data.new()
	var spos : PackedVector3Array = output.addStream( "position", FlowData.DataType.Vector )

	var uniform_interval = maxf( settings.uniform_interval, 0.01 )

	for path_3d in path3d_nodes:
		var curve : Curve3D = path_3d.curve
		curve.bake_interval = uniform_interval
		var samples : PackedVector3Array = curve.get_baked_points()
		var base = spos.size()
		spos.resize( base + samples.size() )
		for idx in range( samples.size() ):
			spos[base + idx] = path_3d.transform * samples[idx]

	set_output( 0, output )
