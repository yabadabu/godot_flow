@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Nodes",
		"settings" : ScanNodesNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generate points from existing nodes",
	}

func find_nodes_in_custom_group( ctx : FlowData.EvaluationContext, group_name: String) -> Array[ Node3D ]:
	var scene_root = ctx.owner.get_tree().root
	var all_nodes = ctx.owner.get_tree().get_nodes_in_group( group_name )
	
	# Filter to only include nodes in the current scene
	var scene_nodes : Array[ Node3D ] = []
	for node in all_nodes:
		var node3d := node as Node3D
		if node3d:
		#if scene_root.is_ancestor_of(node):
			scene_nodes.append(node3d)
	
	return scene_nodes

func importMetaData( output, nodes ):
	var nsamples = nodes.size()
	var streams_by_name : Dictionary = {}
	for idx in range( nsamples ):
		var node = nodes[idx]
		var metas = node.get_meta_list()
		for meta in metas:
			var value = node.get_meta( meta )
			if value == null:
				continue
			var value_data_type = getFlowDataTypeFromGdScriptType( typeof(value) )
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

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var group_name = getSettingValue( ctx, "group_name" )
	var nodes = find_nodes_in_custom_group( ctx, group_name )
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
	
	set_output( 0, output )
