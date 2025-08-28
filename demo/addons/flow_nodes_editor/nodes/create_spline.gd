@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Create Spline",
		"settings" : CreateSplineNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Splines", "data_type": FlowData.DataType.NodePath }],
		"tooltip" : 
			"Generates a spline from all the input points." + 
			""
	}

func spawnNode( root : Node, class_to_spawn ):
	var new_node = class_to_spawn.new()
	#new_node.set_meta("flow_owner", name )	
	new_node.owner = root
	return new_node
	
func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var in_trs := in_data.getTransformsStream()
	if in_trs == null:
		setError( "Invalid input. Missing required attributes %s/%s/%s" % [ FlowData.AttrPosition, FlowData.AttrRotation, FlowData.AttrSize ])
		return
		
	var root = ctx.owner
	var node_tree = root.get_tree()
	var scene_root = node_tree.current_scene
	var path = spawnNode( scene_root, Path3D )
	root.add_child( path )
	path.name = "Spline"
	path.curve  = Curve3D.new()
	var num_idxs : int = in_trs.size()
	for idx in range( num_idxs ):
		var pos : Vector3 = in_trs.positions[idx]
		var in_tan : Vector3 = Vector3.ZERO
		var out_tan : Vector3 = Vector3.ZERO
		if idx > 0 and idx < num_idxs - 1:
			var dir = in_trs.positions[idx+1] - in_trs.positions[idx-1]
			var ndir = dir.normalized() * 0.5
			in_tan = -ndir
			out_tan = ndir
		path.curve.add_point( pos, in_tan, out_tan )
		#print( "  pos[%d]: = %s" % [idx, pos ] )
	var output := FlowData.Data.new()
	output.registerStream( "node", [path], FlowData.DataType.NodePath )
	set_output( 0, output )	
