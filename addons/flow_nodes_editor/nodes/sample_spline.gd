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
	output.addCommonStreams( 0 )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )

	var uniform_interval = maxf( settings.uniform_interval, 0.01 )

	for path_3d in path3d_nodes:
		var curve : Curve3D = path_3d.curve
		curve.bake_interval = uniform_interval
		var base = spos.size()
		var curve_length := curve.get_baked_length()
		var num_samples = curve.get_baked_points().size()
		spos.resize( base + num_samples )
		srot.resize( base + num_samples )
		ssize.resize( base + num_samples)
		for idx in range( num_samples ):
			var offset = idx * curve_length / float(num_samples)
			var t : Transform3D = curve.sample_baked_with_rotation( offset )
			spos[base + idx] = path_3d.transform * t.origin
			
			var b : Basis = path_3d.transform.basis * t.basis
			srot[base + idx] = FlowData.basisToEuler( b )
			
			ssize[base + idx] = Vector3.ONE

	set_output( 0, output )
