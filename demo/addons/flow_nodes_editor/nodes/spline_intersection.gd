@tool
extends FlowNodeBase

@export var threshold : float = 0.01
@export var test : int = 0
@export var show_1 : bool = true
@export var show_2 : bool = true
var num_tests : int = 0

func _init():
	meta_node = {
		"title" : "Spline Intersection",
		"category" : "Spatial",
		"ins" : [
			  { "label": "Splines", "data_type": FlowData.DataType.NodePath }
		],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Find intersections between the input splines\n" 
	}

func registerCandidate( container : PackedInt32Array, idx : int ):
	container.append( idx )

func filterArray( c : PackedInt32Array, max_id : int ) -> PackedInt32Array:
	
	if trace:
		print( "In candidates1:%d" % [ c.size() ])
		for q in c:
			print( q ) 
	var out : PackedInt32Array
	for idx in range( c.size() ):
		if idx > 0:
			if c[idx] == c[idx-1]:
				continue
		if out.size() > 0:
			if out[ out.size() - 1 ] != c[idx] - 1:
				out.append( out[ out.size()-1 ] + 1 )
				out.append( c[idx] - 1 )
		else:
			out.append( c[idx] - 1 )
		out.append( c[idx] )

	if out.size() > 0:
		var last_stored = out[ out.size() - 1 ]
		if last_stored + 1 < max_id:
			if trace: print( "Last stored is %d. MaxSize:%d" % [ last_stored, max_id ] )
			out.append( last_stored + 1 )
		
	if trace: 
		print( "out candidates1:%d " % [ out.size() ])
		for q in out:
			print( q ) 
	return out

func splineVsSpline( d1 : Dictionary, d2 : Dictionary, output: PackedVector3Array ):
	var tree : GDKdTree = d1.tree
	var pos1 : PackedVector3Array = d1.positions
	var pos2 : PackedVector3Array = d2.positions
	var nearest_indices := tree.find_nearest_indices( pos2 )
	
	var pcandidates1 : PackedInt32Array
	var pcandidates2 : PackedInt32Array
	for i2 in range( pos2.size() ):
		var i1 := nearest_indices[ i2 ]
		var d = (pos2[ i2 ] - pos1[i1]).length()
		if d < threshold:
			registerCandidate( pcandidates1, i1 )
			registerCandidate( pcandidates2, i2 )
			if trace: FlowPlugin.get_instance().debug_line( pos1[i1], pos2[i2], Color.RED )
	pcandidates1.sort()
	pcandidates2.sort()
	
	var candidates1 := filterArray( pcandidates1, nearest_indices.size() )
	var candidates2 := filterArray( pcandidates2, nearest_indices.size() )

	if trace:
		for id in candidates1:
			FlowPlugin.get_instance().debug_text( pos1[id], "%d" % id, Color.YELLOW )
		for id in candidates2:
			FlowPlugin.get_instance().debug_text( pos2[id], "%d" % id, Color.CYAN )
	
	for idx1 in range( candidates1.size() - 1):
		var src1 = candidates1[ idx1 ]
		var dst1 = candidates1[ idx1 + 1 ]
		if src1 + 1 != dst1:
			if trace: print( "Skipping idx1 %d as %d + 1 != %d" % [ idx1, src1, dst1 ] )
			continue
		var p1 := pos1[ src1 ]
		var q1 := pos1[ dst1 ]
		for idx2 in range( candidates2.size() - 1):
			var src2 = candidates2[ idx2 ]
			var dst2 = candidates2[ idx2 + 1 ]
			if src2 + 1 != dst2:
				if trace: print( "Skipping idx1 %d as %d + 1 != %d" % [ idx2, src2, dst2 ] )
				continue
			var p2 := pos2[ src2 ]
			var q2 := pos2[ dst2 ]
			
			var normal : Vector3 = (( q1 - p1 ).cross( q2 - p2 )).normalized()
			var axisX := ( q1 - p1 ).normalized()
			var axisY := normal.cross( axisX )
			
			var u1 := Vector2( axisX.dot( p1 ), axisY.dot( p1 ))
			var w1 := Vector2( axisX.dot( q1 ), axisY.dot( q1 ))
			var u2 := Vector2( axisX.dot( p2 ), axisY.dot( p2 ))
			var w2 := Vector2( axisX.dot( q2 ), axisY.dot( q2 ))
			
			var points2d := Geometry2D.get_closest_points_between_segments( u1, w1, u2, w2 )
			if points2d[0].distance_to( u1 ) < 0.01 or points2d[0].distance_to( w1 ) < 0.01 or points2d[1].distance_to( u2 ) < 0.01 or points2d[1].distance_to( w2) < 0.01:
					continue
			if trace: print( "Checking d1:%d-%d vs d2:%d-%d" % [ src1, dst1, src2, dst2 ])
			var points := Geometry3D.get_closest_points_between_segments( p1, q1, p2, q2 )
			var d : float = ( points[1] - points[0] ).length()
			if d < threshold:
				#var pq1 := q1 - p1
				#var v1 : Vector3 = points[0] - p1
				#var w1 : Vector3 = points[0] - q1
				#if pq1.dot( v1 ) * pq1.dot( w1 ) >= 0:
					#continue
				#var pq2 := q2 - p2
				#var v2 : Vector3 = points[1] - p2
				#var w2 : Vector3 = points[1] - q2
				#if pq2.dot( v2 ) * pq2.dot( w2 ) >= 0:
					#continue
				var mid := ( points[0] + points[1] ) * 0.5
				if true or output.size() == 0 or ( output[ output.size() - 1 ] - mid).length() > threshold * 2:
					if test == num_tests or test == -1:
						output.append( mid )
						if trace: 
							FlowPlugin.get_instance().debug_text( points[0], "%d-0" % output.size(), Color.MAGENTA )
							FlowPlugin.get_instance().debug_text( points[1], "%d-1" % output.size(), Color.MAGENTA )
							print( "  -> Saving result")
						#var dd : float = 5.0
						#output.append( p1  + Vector3.UP * dd )
						#output.append( q1  + Vector3.UP * d )
						#output.append( p2  - Vector3.UP * dd )
						#output.append( q2  - Vector3.UP * d )
						#output.append( points[1]  - Vector3.UP * d * 2 )
						#output.append( points[0]  + Vector3.UP * d * 2 )
				num_tests += 1

	if trace:
		if show_1:
			for id in candidates1:
				output.append( pos1[id] )
		if show_2:
			for id in candidates2:
				output.append( pos2[id] )
		
func execute( ctx : FlowData.EvaluationContext ):
	var in_data = getInput(ctx, 0)
	var path3d_nodes = in_data.getContainerChecked("node", FlowData.DataType.NodePath, ctx, self)
	if path3d_nodes == null:
		return
	num_tests = 0
	
	FlowPlugin.get_instance().clear_debug_draw()
	
	var all_intersections : PackedVector3Array

	var uniform_interval : float = threshold 
	var samples_size := Vector3( uniform_interval, uniform_interval, uniform_interval )
	
	var data = path3d_nodes.map( func( obj ):
		var curve : Curve3D = obj.curve
		var prev_interval := curve.bake_interval
		curve.bake_interval = uniform_interval
		var positions := curve.get_baked_points()

		var tree := GDKdTree.new()
		tree.set_points( positions )
		
		curve.bake_interval = prev_interval 
		return { 
			"tree" : tree, 
			"positions" : positions, 
			"curve" : curve,
			"obj" : obj
			}
	)
	
	var num_curves = data.size()
	
	var i1 : int = 0
	while i1 < num_curves:
		var d1 : Dictionary = data[i1]
		var i2 : int = i1 + 1
		while i2 < num_curves:
			var d2 : Dictionary = data[i2]
			print( "Testing spline %s vs %s" % [ d1.obj.name, d2.obj.name ])
			splineVsSpline( d1, d2, all_intersections )
			i2 += 1
			
			if false:
				i2 = 100
				i1 = 100
		i1 += 1
		
	var nsamples = all_intersections.size()
	
	var all_sizes : PackedVector3Array
	for i in range( all_intersections.size( )):
		all_sizes.append( samples_size )
	
	var out_data := FlowData.Data.new()
	out_data.addCommonStreams( nsamples )
	out_data.registerStream(FlowData.AttrPosition, all_intersections)
	out_data.registerStream(FlowData.AttrSize, all_sizes)
	setOutput(ctx, 0, out_data)
