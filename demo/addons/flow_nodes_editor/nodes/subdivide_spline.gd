@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Subdivide Spline",
		"settings" : SubdivideSplineNodeSettings,
		"category" : "Spatial",
		"ins" : [{ "label": "Splines", "data_type": FlowData.DataType.NodePath }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Subdivides a spline based on a grammar definition.\n" 
		+ "A, B, C           sequence\n" 
		+ "[A, B]            all-or-none group\n" 
		+ "A+                one or more\n" 
		+ "A*                zero or more, fill as much as possible\n" 
		+ "A3                exactly three times\n" 
		+ "[A, B]3           exact group repeat count\n" 
		+ "<A, B, C>         fallback: try A, else B, else C\n" 
		+ "{A:2, B:1, C:1}   weighted random choice"
	}

func execute( ctx : FlowData.EvaluationContext ):
	
	var in_data = get_input(0)
	var path3d_nodes = in_data.getContainerChecked( "node", FlowData.DataType.NodePath )
	if path3d_nodes == null:
		setError( "Input are not splines")
		return null	
	
	var grammar = settings.grammar
	var evaluator = GrammarEvaluator.new()
	var pieces = {
		"A" : { "length" : 0.5 },
		"B" : { "length" : 1.0 },
		"C" : { "length" : 1.5 },
		"D" : { "length" : 1.0 },
	}
	if not evaluator.parseString( grammar ):
		for err in evaluator.getErrors():
			print( "  Error: %s" % err )
		return
		
	if settings.trace:
		evaluator._ast.dump()

	evaluator.setPieces( pieces )
	
	for path_3d in path3d_nodes:
		var curve : Curve3D = path_3d.curve	
		var total_length : float = curve.get_baked_length()
	
		var generated_symbols := evaluator.sample( total_length )
		
		var num_points : int = generated_symbols.size()
		var output := FlowData.Data.new()
		output.addCommonStreams( num_points )
		var spos := output.getVector3Container( FlowData.AttrPosition )
		var srot := output.getVector3Container( FlowData.AttrRotation )
		var ssize := output.getVector3Container( FlowData.AttrSize )
		
		var distances : PackedFloat32Array
		var acc : float = 0.0
		for symbol in generated_symbols:
			var length : float = pieces.get( symbol ).length
			distances.append( length )
			acc += length
		
		if settings.trace:
			print( "Total distance covered %f / %f using %d symbols" % [ acc, total_length, generated_symbols.size() ])
		
		var offset := 0.0
		var offsets_stream : PackedFloat32Array
		for idx in range( generated_symbols.size() ):
			var length := distances[idx]
			var t : Transform3D = curve.sample_baked_with_rotation( offset + length * 0.5 )
			spos[ idx ] = path_3d.transform * t.origin
			var b : Basis = path_3d.transform.basis * t.basis
			srot[ idx ] = FlowData.basisToEuler( b )
			ssize[ idx ] = Vector3.ONE * length
			offsets_stream.append( offset )
			offset += length

		output.registerStream( "symbol", generated_symbols, FlowData.DataType.String )
		output.registerStream( "offset", offsets_stream, FlowData.DataType.Float )

		set_output( 0, output )
	
