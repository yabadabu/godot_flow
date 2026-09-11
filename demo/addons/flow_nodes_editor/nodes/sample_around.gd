@tool
extends FlowNodeBase

@export var radius : float = 1.0
@export var max_radius : float = 3.0
@export var max_points : int = 100

func _init():
	meta_node = {
		"title" : "Sample Around",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates new points randomly around the input positions in the plane XZ",
	}

class Bridson:
	var active : PackedInt32Array
	var candidates_positions : PackedVector3Array
	var candidates_rads : PackedFloat32Array
	var radius : float = 1.0
	var max_radius : float = 3.0
	var spatial : GDKdTree
	var sources_spatial : GDKdTree
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	var ordered_generation : bool = true
	var new_positions : PackedVector3Array
	var next_idx : int = 0

	func addSources( in_trs : FlowData.TransformsStream ):
		var in_size : int = in_trs.size()
		spatial.set_points( in_trs.positions )	
		sources_spatial.set_points( in_trs.positions )	
		active.resize( in_size )
		for i in range(in_size):
			active[i] = i
		candidates_positions.append_array( in_trs.positions )
		candidates_rads.resize( in_size )
		for i in range(in_size):
			candidates_rads[i] = ( in_trs.sizes[ i ] * Vector3(1,0,1) ).length()

	func insert( new_pos : Vector3 ) -> int:
		var new_idx = spatial.add_point( new_pos )
		new_positions.append( new_pos )
		return new_idx
		
	func suggestCandidate( p : Vector3, r : float ) -> Vector3:
		for i : int in range( 8 ):
			var angle : float = rng.randf() * PI * 2.0
			var rad_factor = rng.randf_range( 1.0, 2.0 )
			var dir = Vector3( cos(angle), 0, sin(angle))
			var candidate = p + dir * ( r + radius * rad_factor ) * 1.02 * 0.5
			if spatial.is_close( candidate, radius ):
				continue
			if not sources_spatial.is_close( candidate, max_radius ):
				continue
			return candidate
		return Vector3.INF

	func tryAdd( ) -> bool:
		var active_idx : int = rng.randi_range(0, active.size()-1 )
		var point_id : int = active[ active_idx ]
		var center_pos : Vector3 = candidates_positions[ point_id ]
		var center_rad : float = candidates_rads[ point_id ]
		var new_pos = suggestCandidate( center_pos, center_rad )
		#print( "Testing point_id %d/%d A:%d at %f,%f-> %f,%f" % [ point_id, active.size(), active_idx, center_pos.x, center_pos.z, new_pos.x, new_pos.z ])
		if new_pos != Vector3.INF:
			var new_idx = insert( new_pos )
			next_idx = ( next_idx + 1 )
			candidates_positions.append( new_pos )
			candidates_rads.append( radius )
			active.push_back( new_idx )
			#print( "  Success. Now we have %d active points. next_idx is %d" % [ active.size(), next_idx ])
			return true
		#print( "Failed. Discarting point %d" % [ active_idx ])
		active.remove_at( active_idx )
		return false

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	var in_trs : FlowData.TransformsStream = in_data.getTransformsStream()
	if in_trs == null:
		setError(ctx,  "Input does not provide position, rotation or scale streams" )
		return

	var bridson = Bridson.new()
	bridson.spatial = GDKdTree.new()
	bridson.sources_spatial = GDKdTree.new()
	bridson.radius = radius
	bridson.max_radius = max_radius
	bridson.rng.seed = random_seed
	bridson.addSources( in_trs )

	for i in range( max_points ):
		bridson.tryAdd()
		if bridson.active.is_empty():
			print( "At iter %d no more active points" % [ i ])
			break

	var out_data := FlowData.Data.new()
	out_data.addCommonStreams( 0 )
	var spos := out_data.getVector3Container( FlowData.AttrPosition )
	var srot := out_data.getVector3Container( FlowData.AttrRotation )
	var ssize := out_data.getVector3Container( FlowData.AttrSize )
	for p in bridson.new_positions:
		spos.append( p )
		ssize.append( Vector3.ONE * bridson.radius )
		srot.append( Vector3.ZERO )
	
	setOutput(ctx, 0, out_data )
