@tool
extends FlowNodeBase

const min_interval := 0.1

func _init():
	meta_node = {
		"title" : "Sample Spline",
		"settings" : SampleSplineNodeSettings,
		"ins" : [{ "label": "Splines", "data_type": FlowData.DataType.NodePath }],
		"outs" : [{ "label" : "Out" }],
	}
	
func get_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() == 0:
		return Rect2()
	
	var min_x = polygon[0].x
	var max_x = polygon[0].x
	var min_y = polygon[0].y
	var max_y = polygon[0].y
	
	for point in polygon:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)	

func points3d_to_polygon2d(points3d : PackedVector3Array) -> PackedVector2Array:
	var num_points := points3d.size()
	var polygon := PackedVector2Array()
	polygon.resize( num_points )
	for i in range(num_points):
		polygon[i] = Vector2( points3d[i].x, points3d[i].z )
	return polygon

func addDistanceAttribute( output : FlowData.Data, target_points : PackedVector3Array ):
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var sdists : PackedFloat32Array = output.addStream( "distance", FlowData.DataType.Float )
	sdists.resize( output.size() )
	
	var time_start_kdtree := Time.get_ticks_usec()
	var kdtree := GDKdTree.new()
	kdtree.set_points( target_points )
	if settings.trace: print( "spline.kdtree: %f (%d)" % [ Time.get_ticks_usec() - time_start_kdtree, target_points.size() ])
	
	var time_start_distance := Time.get_ticks_usec()
	var nearest_indices := kdtree.find_nearest_indices( spos )
	for src_idx in range( nearest_indices.size() ):
		var nearest_idx = nearest_indices[src_idx]
		sdists[src_idx] = ( spos[src_idx] - target_points[nearest_idx] ).length()
	if settings.trace: print( "spline.dist: %f" % [ Time.get_ticks_usec() - time_start_distance ])	

func rasterizeCurveInXZ( curve : Curve3D, uniform_interval : float, base : int ) -> PackedVector2Array:
	var points := curve.tessellate(2, 5)
	var points_size := points.size()
	var new_size = base + points_size
	
	# This uses XZ coords of input points
	var poly2d := points3d_to_polygon2d( points )
	var bounds = get_polygon_bounds( poly2d )
	bounds.position -= Vector2( 0.1, 0.1 )
	bounds.end += Vector2( 0.1, 0.1 )	
	
	var new_points := PackedVector2Array()
	var hits := PackedFloat32Array()
	
	var time_start_grid := Time.get_ticks_usec()
	var height : float = bounds.size.y
	var num_steps : int = round( height / uniform_interval )
	var py : float = bounds.position.y
	var dy : float = uniform_interval
	var dx : float = uniform_interval
	for y in range( num_steps ):

		var left := Vector2( bounds.position.x, py )
		var right  := Vector2( bounds.end.x, py )
		var p0 := poly2d[ points_size - 1 ]
		hits.clear()
		for segment_id in range( points_size ):
			var p1 := poly2d[ segment_id ]
			var hit = Geometry2D.segment_intersects_segment( p0, p1, left, right )
			if hit:
				hits.append( hit.x )
			p0 = p1
		
		var num_hits = hits.size()
		if num_hits > 0 && (num_hits % 2 == 0):
			hits.sort()
			for q0 in range( 0, num_hits, 2 ):
				var px0 := hits[q0]
				var px1 := hits[q0+1]
				px0 = round( px0 / dx ) * dx
				px1 = round( px1 / dx ) * dx
				var width = px1 - px0
				var idx = int( width / dx )
				for x in range( idx ):
					new_points.append( Vector2( px0, py ) )
					px0 += dx 
				new_points.append( Vector2( px0, py ) )
		py += dy
	if settings.trace: print( "spline.grid: %f" % [ Time.get_ticks_usec() - time_start_grid ])	
	return new_points

func execute( ctx : FlowData.EvaluationContext ):
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return null
		
	var trace := settings.trace
		
	var in_data = get_input(0)
	var path3d_nodes = in_data.getContainerChecked( "node", FlowData.DataType.NodePath )
	if path3d_nodes == null:
		setError( "Input are not splines")
		return null
	print( "path3d_nodes", path3d_nodes)

	var output := FlowData.Data.new()
	output.addCommonStreams( 0 )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	
	var uniform_interval = getSettingValue( ctx, "uniform_interval" )
	if uniform_interval < min_interval:
		uniform_interval = min_interval
		settings.uniform_interval = uniform_interval
	
	if getSettingValue( ctx, "fill_curve" ):
		for path_3d in path3d_nodes:
			var curve : Curve3D = path_3d.curve
			var base = spos.size()

			var new_points := rasterizeCurveInXZ( curve, uniform_interval, base )
			
			for hit in new_points:
				var hit3d = path_3d.transform * Vector3( hit.x, 0.0, hit.y )
				spos.append( hit3d )
				srot.append( Vector3.ZERO )
				
			if settings.distance_attribute:
				curve.bake_interval = uniform_interval * 2.0
				var border_points = curve.get_baked_points()
				
				var path_transform = path_3d.transform
				for i in range( border_points.size() ):
					border_points[i] = path_transform * border_points[i]
				addDistanceAttribute( output, border_points )
		
	else:
		for path_3d in path3d_nodes:
			var curve : Curve3D = path_3d.curve
			curve.bake_interval = uniform_interval
			var base = spos.size()
			var curve_length := curve.get_baked_length()
			var num_samples = curve.get_baked_points().size()
			
			if getSettingValue( ctx, "sample_segments_centers" ):
				if num_samples > 2:
					num_samples -= 1
					spos.resize( base + num_samples )
					srot.resize( base + num_samples )
					ssize.resize( base + num_samples )
					for idx in range( num_samples ):
						var offset0 = idx * curve_length / float(num_samples )
						var offset1 = ( idx + 1 ) * curve_length / float(num_samples )
						var t0 : Transform3D = curve.sample_baked_with_rotation( offset0 )
						var t1 : Transform3D = curve.sample_baked_with_rotation( offset1 )
						var p0 : Vector3 = path_3d.transform * t0.origin
						var p1 : Vector3 = path_3d.transform * t1.origin
						spos[base + idx] = ( p0 + p1 ) * 0.5
						var front = p1 - p0
						var b = Basis.looking_at( front )
						srot[base + idx] = FlowData.basisToEuler( b )
						ssize[base + idx] = Vector3( 1.0, 1.0, front.length() )
			
			else:
				spos.resize( base + num_samples )
				srot.resize( base + num_samples )
				for idx in range( num_samples ):
					var offset = idx * curve_length / float(num_samples - 1)
					var t : Transform3D = curve.sample_baked_with_rotation( offset )
					spos[base + idx] = path_3d.transform * t.origin
					
					var b : Basis = path_3d.transform.basis * t.basis
					srot[base + idx] = FlowData.basisToEuler( b )
		uniform_interval = 1.0
				
	# All the samples have the same size
	if ssize.size() != spos.size():
		ssize.resize( spos.size() )
		var sample_size = Vector3.ONE * uniform_interval
		ssize.fill(sample_size)

	set_output( 0, output )
