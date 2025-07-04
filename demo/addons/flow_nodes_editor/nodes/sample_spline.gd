@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Sample Spline",
		"settings" : SampleSplineNodeSettings,
		"ins" : [],
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

func curve_to_polygon(curve: Curve3D, resolution: int = 100) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	for i in range(resolution + 1):
		var t = float(i) / resolution
		var pos = curve.sample_baked(t * curve.get_baked_length())
		polygon.append(Vector2( pos.x, pos.z ))
	return polygon
	
func point_to_line_segment_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	
	if line_vec.length_squared() == 0:
		return point_vec.length()
	
	var t = clamp(point_vec.dot(line_vec) / line_vec.length_squared(), 0.0, 1.0)
	var projection = line_start + t * line_vec
	
	return point.distance_to(projection)
		
func point_to_polygon_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var min_distance = INF
	
	for i in range(polygon.size()):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % polygon.size()]
		var distance = point_to_line_segment_distance(point, p1, p2)
		min_distance = min(min_distance, distance)
	
	return min_distance	
	
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
	
	# Compute distances using fast sweeping or similar algorithm
	return compute_distance_transform(sdf_grid, edge_points, polygon, bounds, res_x, res_y)

func compute_distance_transform(grid: Array, edge_points: Array, polygon: PackedVector2Array, bounds: Rect2, res_x: int, res_y: int) -> Array:
	var step_x = bounds.size.x / res_x
	var step_y = bounds.size.y / res_y
	
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
			var distance = point_to_polygon_distance(world_pos, polygon)
			
			grid[y][x] = distance * (-1 if is_inside else 1)
	
	return grid

func findNodesOfType(root: Node, type_name: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	
	# Check if current node matches
	if root.get_class() == type_name:
		found_nodes.append(root)
	
	# Recursively check children
	for child in root.get_children():
		found_nodes.append_array(findNodesOfType(child, type_name))
	
	return found_nodes	

func execute( ctx : FlowData.EvaluationContext ):
	
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

	var uniform_interval = getSettingValue( ctx, "uniform_interval" )
	uniform_interval = maxf( uniform_interval, 0.01 )

	if getSettingValue( ctx, "fill_curve" ):
		var sdists : PackedFloat32Array = output.addStream( "distance", FlowData.DataType.Float )
		for path_3d in path3d_nodes:
			var curve : Curve3D = path_3d.curve
			var polygon = curve_to_polygon(curve)
			var bounds = get_polygon_bounds(polygon)
			var dim_x = round( bounds.size.x / uniform_interval )
			var dim_z = round( bounds.size.y / uniform_interval )
			#print( "bounds", bounds )
			var grid = compute_optimized_sdf( curve, bounds, dim_x, dim_z )
			#print( grid )
			var dy = uniform_interval
			var dx = uniform_interval
			var py = bounds.position.y
			for gy in grid:
				#print( "New line..", py)
				var px = bounds.position.x
				for d in gy:
					if d <= 0:
						var pos = Vector3( px, 0.0, py )
						spos.append( path_3d.transform * pos )
						srot.append( Vector3.ZERO )
						ssize.append( Vector3.ONE * uniform_interval )
						sdists.append( -d )
					px += dx
				py += dy
		
	else:
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
