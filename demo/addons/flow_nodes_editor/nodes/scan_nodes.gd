@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Nodes",
		"settings" : ScanNodesNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generate points from existing non-graph nodes in the scene",
	}
	
func get_scene_root_node3d( current : Node3D ) -> Node3D:
	while current and current.get_parent_node_3d():
		current = current.get_parent_node_3d()
	return current

func find_nodes_matching_filters( ctx : FlowData.EvaluationContext, group_name: String, filter_by_class_name: String) -> Array[ Node3D ]:
	var all_nodes : Array[Node] = []
	#var scene_root = ctx.owner.get_tree().root
	if group_name:
		all_nodes = ctx.owner.get_tree().get_nodes_in_group( group_name )
	elif ctx.owner:
		var root = get_scene_root_node3d( ctx.owner )
		all_nodes = root.get_children()
	print( "all_nodes", all_nodes )
	
	# Filter to only include nodes in the current scene
	var scene_nodes : Array[ Node3D ] = []
	for node in all_nodes:
		var node3d := node as Node3D
		if node3d:
			if filter_by_class_name and not node3d.is_class( filter_by_class_name ):
				print( "%s.%s discarted by class_name %s" % [ node3d.name, node3d.get_class(), filter_by_class_name ])
				continue
		#if scene_root.is_ancestor_of(node):
			scene_nodes.append(node3d)
	print( "scene_nodes", scene_nodes)
	return scene_nodes

func importMetaData( output, nodes ):
	var nsamples = nodes.size()
	for idx in range( nsamples ):
		var node = nodes[idx]
		var metas = node.get_meta_list()
		for meta in metas:
			var value = node.get_meta( meta )
			if value == null:
				continue
			var value_data_type = getFlowDataTypeFromObject( value )
			if value_data_type == FlowData.DataType.Invalid:
				continue
			if not output.hasStream( meta ):
				output.addStream( meta, value_data_type )
			var stream = output.findStream( meta )
			assert( stream )
			if stream.data_type != value_data_type:
				print( "Node %d (%s), meta: %s has type %d but the registered stream as type %d" % [ idx, node.name, meta, value_data_type, stream.type ])
				continue
			if value_data_type == FlowData.DataType.Bool:
				value = 1 if value else 0
			stream.container[ idx ] = value	
			#print( "Saved as %s" % [ stream.container[ idx ] ])

func get_property_path( current, path_parts ):
	for key in path_parts:
		if current == null:
			return null
		if not current.has_method("get"): #" or not current.has_property(key):
			return null
		current = current.get(key)
	return current
	
func importProperty( output, nodes, prop_path ):
	var nsamples = nodes.size()
	var stream = null
	
	var parts = prop_path.split( ":" )
	var stream_name = parts[ parts.size() - 1 ]
	
	for idx in range( nsamples ):
		var node = nodes[idx]
		var value = get_property_path( node, parts )
		if value == null:
			continue
		var value_data_type = getFlowDataTypeFromObject( value )
		if value_data_type == FlowData.DataType.Invalid:
			continue
		if not stream:
			output.addStream( stream_name, value_data_type )
			stream = output.findStream( stream_name )
		
		if stream.data_type != value_data_type:
			print( "Node %d (%s), meta: %s has type %d but the registered stream as type %d" % [ idx, node.name, prop_path, value_data_type, stream.type ])
			continue
		if value_data_type == FlowData.DataType.Bool:
			value = 1 if value else 0
		stream.container[ idx ] = value	

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var group_name = getSettingValue( ctx, "group_name" )
	var filter_by_class_name = getSettingValue( ctx, "filter_by_class_name" )
	var nodes = find_nodes_matching_filters( ctx, group_name, filter_by_class_name )
	
	var nsamples = nodes.size()
	output.addCommonStreams( nsamples )
	
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	for idx in range( nsamples ):
		var node = nodes[idx]
		spos[idx] = node.global_position
		ssize[idx] = node.scale
		var b : Basis = node.global_transform.basis
		srot[idx] = FlowData.basisToEuler( b )
		
	if getSettingValue( ctx, "import_metadata" ) as bool:
		importMetaData( output, nodes )
	
	for prop_name in settings.import_properties:
		if prop_name:
			importProperty( output, nodes, prop_name )
	
	set_output( 0, output )
