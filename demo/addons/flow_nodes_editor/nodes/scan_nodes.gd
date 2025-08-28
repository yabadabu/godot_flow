@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Scan Nodes",
		"settings" : ScanNodesNodeSettings,
		"scans_scene" : true,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generate points from existing non-flowgraph nodes in the scene\nCan filter by class name, group.\nMetadata values can optionally be imported\nYou can also import properties of the nodes, even with a\nsubpath property like mesh:text if the nodes are a MeshInstance3D with meshes of type TextMesh.",
	}
	
# material[0]:albedo_color
# name

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
			print( "obj %s" % [ current ])
			return null
		if settings.trace:
			print( "current is %s. (%s)" % [ current, key ] )
		
		# Custom hand-made solution
		if key == "material[0]":
			current = current.get_active_material(0)
		else:
			current = current.get(key)
		
		# Testing get_class to return the class_name of each node
		if typeof( current ) == TYPE_CALLABLE:
			current = current.call()
			
	if settings.trace:
		print( "Final %s returned value is %s Type:%d" % [ path_parts, current, typeof( current ) ] )
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
			# Special conversion StringName becomes a String. For example reading name
			if typeof( value ) == TYPE_STRING_NAME:
				value_data_type = FlowData.DataType.String
				value = String( value )
			elif typeof( value ) == TYPE_COLOR:
				value_data_type = FlowData.DataType.Vector
				value = Vector3( value.r, value.g, value.b )	# Alpha is not read!
			else:
				continue
		if not stream:
			output.addStream( stream_name, value_data_type )
			stream = output.findStream( stream_name )
		
		if stream.data_type != value_data_type:
			print( "Node %d (%s), meta: %s has type %d but the registered stream as type %d" % [ idx, node.name, prop_path, value_data_type, stream.type ])
			continue
		
		# Special cases
		if value_data_type == FlowData.DataType.Bool:
			value = 1 if value else 0
			
		stream.container[ idx ] = value	

func get_aabb_of_node( node3d : Node3D ) -> AABB:
	var combined_aabb := AABB()  # Starts as invalid (zero size)
	if node3d is MeshInstance3D:
		if node3d.mesh:
			return node3d.mesh.get_aabb()
	elif node3d is Path3D:
		var points : PackedVector3Array = node3d.curve.get_baked_points()
		if points.size() > 0:
			var pmin = points[0]
			var pmax = points[0]
			for p in points:
				pmin = pmin.min( p )
				pmax = pmax.max( p )
			var half = ( pmax - pmin )
			return AABB( pmin, half )
			
	# This is not working correctly
	elif node3d is CollisionShape3D:
		var shape = node3d.shape
		if shape:
			if shape is BoxShape3D:
				var box_shape = shape as BoxShape3D
				return AABB( node3d.position - box_shape.size * 0.5, box_shape.size )
		
	return combined_aabb

func get_combined_aabb(root: Node3D) -> AABB:
	var combined_aabb := get_aabb_of_node( root )
	for child in root.get_children():
		var child_aabb := get_aabb_of_node( child )
		if combined_aabb.size == Vector3.ZERO:
			combined_aabb = child_aabb
		else:
			combined_aabb = combined_aabb.merge(child_aabb)
	return combined_aabb

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var filter_by_class_name = getSettingValue( ctx, "filter_by_class_name" )
	var nodes = findNodesMatchingFilters( ctx, filter_by_class_name )
	
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
		
		if settings.size_to_bounds:
			var aabb = get_combined_aabb( node )
			ssize[idx] = aabb.size
			spos[idx] = node.transform * ( aabb.position + aabb.size * 0.5 )
			
	if getSettingValue( ctx, "import_metadata" ) as bool:
		importMetaData( output, nodes )
	
	for prop_name in settings.import_properties:
		if prop_name:
			importProperty( output, nodes, prop_name )
	
	set_output( 0, output )
