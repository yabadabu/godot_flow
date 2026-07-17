@tool
extends FlowNodeBase

@export var attribute_name : String = "@auto"

func _init():
	meta_node = {
		"title" : "Get Bounds",
		"category" : "Uncategorized",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Returns the bounds associated to the node/mesh",
	}
	
func get_bounds_of_resource( res : Resource ):
	if not res:
		return null
	if res is Mesh:
		return (res as Mesh).get_aabb()
	elif res is Curve3D or res is Curve2D:
		var points : PackedVector3Array = res.get_baked_points()
		if points.size() > 0:
			var pmin = points[0]
			var pmax = points[0]
			for p in points:
				pmin = pmin.min( p )
				pmax = pmax.max( p )
			var half = ( pmax - pmin )
			return AABB( pmin, half )
	return null

func find_attribute( in_data : FlowData.Data ):
	if attribute_name == "@auto":
		var streams := in_data.streams.values().filter( func( candidate ) -> bool:
			return candidate.data_type == FlowData.DataType.Resource
			)
		if streams.size() == 1:
			return streams[0]
		return null
	return in_data.findStream( attribute_name )

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()

	var in_stream = find_attribute( in_data )
	if in_stream == null:
		return
	var bounds_container : PackedVector3Array
	bounds_container.resize( in_data.size() )
	if in_stream != null:
		match in_stream.data_type:
			FlowData.DataType.Resource:
				for idx in range( in_stream.container.size() ):
					var res : Resource = in_stream.container[ idx ]
					var aabb = get_bounds_of_resource( res )
					bounds_container[ idx ] = aabb.size
			_:
				print( "Stream has type %s" % FlowData.DataType.keys()[ in_stream.data_type ])
				pass
	out_data.registerStream( "bounds", bounds_container, FlowData.DataType.Vector )
	set_output( 0, out_data )
