@tool
class_name FlowBaseScanNode
extends FlowNodeBase

@export_group("Scan Nodes")
@export var group_name : String
@export var filter_by_name : String
@export var import_metadata : bool = false
@export var import_properties : Array[ StringName ]
@export var required_meta_bool : StringName

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
		if trace:
			print( "current is %s. (%s)" % [ current, key ] )
		
		# Custom hand-made solution
		if key == "material[0]":
			current = current.get_active_material(0)
		else:
			current = current.get(key)
		
		# Testing get_class to return the class_name of each node
		if typeof( current ) == TYPE_CALLABLE:
			current = current.call()
			
	if trace:
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

func importCommon( ctx : FlowData.EvaluationContext, output : FlowData.Data, nodes : Array[Node3D] ):
	if getSettingValue( ctx, "import_metadata" ) as bool:
		importMetaData( output, nodes )
	
	for prop_name in import_properties:
		if prop_name:
			importProperty( output, nodes, prop_name )

func findNodesMatchingFilters( ctx : FlowData.EvaluationContext, filter_by_class_name : String ) -> Array[ Node3D ]:

	var group_name = getSettingValue( ctx, "group_name" )
	var required_meta : StringName = required_meta_bool

	var all_nodes : Array[Node] = []
	if group_name:
		all_nodes = ctx.owner.get_tree().get_nodes_in_group( group_name )
	elif ctx.owner:
		var root = getSceneRootNode3d( ctx.owner )
		all_nodes = root.get_children()
	
	if trace:
		print( "all_nodes", all_nodes )
	
	# Filter to only include nodes in the current scene
	var scene_nodes : Array[ Node3D ] = []
	for node in all_nodes:
		var node3d := node as Node3D
		if node3d:
			if filter_by_class_name and not node3d.is_class( filter_by_class_name ):
				if trace:
					print( "%s.%s discarted by class_name %s" % [ node3d.name, node3d.get_class(), filter_by_class_name ])
				continue

			if not required_meta.is_empty():
				if not node3d.has_meta( required_meta ) or not bool( node3d.get_meta( required_meta ) ):
					continue
	
			scene_nodes.append(node3d)
	return scene_nodes
