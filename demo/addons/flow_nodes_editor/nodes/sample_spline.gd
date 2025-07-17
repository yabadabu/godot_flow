@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Sample Spline",
		"settings" : SampleSplineNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		#"trace" : true
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

func curve_to_polygon(curve: Curve3D, resolution: int = 100) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	for i in range(resolution + 1):
		var t = float(i) / resolution
		var pos = curve.sample_baked(t * curve.get_baked_length())
		polygon.append(Vector2( pos.x, pos.z ))
	return polygon
		
	
func rasterize_line(p1: Vector2, p2: Vector2) -> Array[Vector2]:
	var points : Array[Vector2] = []
	var dx = abs(p2.x - p1.x)
	var dy = abs(p2.y - p1.y)
	var steps = max(dx, dy)
	
	if steps == 0:
		return [p1]
	
	var x_inc = (p2.x - p1.x) / steps
	var y_inc = (p2.y - p1.y) / steps
	
	for i in range(int(steps) + 1):
		var point = Vector2(
			round(p1.x + i * x_inc),
			round(p1.y + i * y_inc)
		)
		points.append(point)
	
	return points	
	
func compute_optimized_sdf(curve: Curve3D, bounds: Rect2, res_x: int, res_y : int) -> Array:
	var polygon = curve_to_polygon(curve, 50)
	var sdf_grid = []
	
	var time_start := Time.get_ticks_usec()	
	
	# Initialize grid
	for y in range(res_y):
		var row = []
		for x in range(res_x):
			row.append(INF)
		sdf_grid.append(row)
	
	var step_x = bounds.size.x / res_x
	var step_y = bounds.size.y / res_y
	
	# Rasterize polygon edges to grid
	var edge_points = []
	for i in range(polygon.size()):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % polygon.size()]
		
		# Convert world coordinates to grid coordinates
		var grid_p1 = Vector2(
			(p1.x - bounds.position.x) / step_x,
			(p1.y - bounds.position.y) / step_y
		)
		var grid_p2 = Vector2(
			(p2.x - bounds.position.x) / step_x,
			(p2.y - bounds.position.y) / step_y
		)
		
		# Rasterize line segment
		var line_points = rasterize_line(grid_p1, grid_p2)
		edge_points.append_array(line_points)
	
	if settings.trace: print( "spline.grid: %f" % [ Time.get_ticks_usec() - time_start ])
	# Compute distances using fast sweeping or similar algorithm
	return compute_distance_transform(sdf_grid, edge_points, polygon, bounds, res_x, res_y)

func compute_distance_transform(grid: Array, edge_points: Array, polygon: PackedVector2Array, bounds: Rect2, res_x: int, res_y: int) -> Array:
	var step_x = bounds.size.x / res_x
	var step_y = bounds.size.y / res_y
	
	var p3d : PackedVector3Array
	for ep in polygon:
		p3d.append( Vector3( ep.x, 0, ep.y ))
	var kdtree := GDKdTree.new()
	kdtree.set_points( p3d )
	
	# Use efficient distance transform algorithm
	for y in range(res_y):
		for x in range(res_x):
			var world_pos = Vector2(
				bounds.position.x + x * step_x,
				bounds.position.y + y * step_y
			)
			
			var is_inside = Geometry2D.is_point_in_polygon(world_pos, polygon)
			if not is_inside:
				continue
			
			var world_pos3d = Vector3( world_pos.x, 0, world_pos.y )
			var nearest_idx = kdtree.find_nearest_idx( world_pos3d )
			var distance = ( world_pos3d - p3d[nearest_idx] ).length()
			
			grid[y][x] = -distance
	
	return grid

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
		
	var path3d_nodes = findNodesOfType(root, "Path3D")

	var output := FlowData.Data.new()
	output.addCommonStreams( 0 )
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )

	var uniform_interval = getSettingValue( ctx, "uniform_interval" )
	uniform_interval = maxf( uniform_interval, 0.01 )
	
	if getSettingValue( ctx, "fill_curve" ):
		var sdists : PackedFloat32Array = output.addStream( "distance", FlowData.DataType.Float )
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
				addDistanceAttribute( output, border_points )
		
	else:
		for path_3d in path3d_nodes:
			var curve : Curve3D = path_3d.curve
			curve.bake_interval = uniform_interval
			var base = spos.size()
			var curve_length := curve.get_baked_length()
			var num_samples = curve.get_baked_points().size()
			
			spos.resize( base + num_samples )
			srot.resize( base + num_samples )
			for idx in range( num_samples ):
				var offset = idx * curve_length / float(num_samples)
				var t : Transform3D = curve.sample_baked_with_rotation( offset )
				spos[base + idx] = path_3d.transform * t.origin
				
				var b : Basis = path_3d.transform.basis * t.basis
				srot[base + idx] = FlowData.basisToEuler( b )
		uniform_interval = 1.0
				
	# All the samples have the same size
	var ssize := output.getVector3Container( FlowData.AttrSize )
	ssize.resize( spos.size() )
	var sample_size = Vector3.ONE * uniform_interval
	ssize.fill(sample_size)

	set_output( 0, output )
