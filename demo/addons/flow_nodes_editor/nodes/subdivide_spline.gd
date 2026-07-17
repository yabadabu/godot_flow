@tool
extends FlowNodeBase

enum eFitBehaviour {
	AlignLeft,
	Autoscale,
	Centered,
	AlignRight,
	Interspace
}

@export var grammar_as_attribute : bool = false:
	set(value):
		grammar_as_attribute = value
		notify_property_list_changed()
		
@export var grammar : String
@export var fit_behaviour : eFitBehaviour = eFitBehaviour.Autoscale
@export_subgroup("Input Attributes", "attribute_")
@export var attribute_symbol : String = "symbol"
@export var attribute_length : String = "bounds.z"
@export var attribute_scalable : String = "scalable"
@export var attribute_grammar : String = "grammar"

@export_range(0.0, 10.0, 0.01, "or_greater")var curve_offset_start : float = 0.0
@export_range(0.0, 10.0, 0.01, "or_greater")var curve_offset_end : float = 0.0

func _init():
	meta_node = {
		"title" : "Subdivide Spline",
		"category" : "Spatial",
		"ins" : [
			  { "label": "Splines", "data_type": FlowData.DataType.NodePath }
			, { "label": "Pieces" } ],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Subdivides a spline based on a grammar definition.\n" 
		+ "[code]A, B, C           sequence\n" 
		+ "[A, B]            all-or-none group\n" 
		+ "A+                one or more\n" 
		+ "A*                zero or more, fill as much as possible\n" 
		+ "A3                exactly three times\n" 
		+ "[A, B]3           exact group repeat count\n" 
		+ "<A, B, C>         fallback: try A, else B, else C\n" 
		+ "{A:2, B:1, C:1}   weighted random choice[/code]"
	}

func exposeParam( name : String ) -> bool:
	if name == "grammar" or name == "attribute_grammar":
		return grammar_as_attribute == ( name == "attribute_grammar" )
	return true

func execute( ctx : FlowData.EvaluationContext ):
	
	var in_data = get_input(0)
	var path3d_nodes = in_data.getContainerChecked( "node", FlowData.DataType.NodePath, self )
	if path3d_nodes == null:
		return
		
	var in_pieces = get_input(1)
	if in_pieces == null:
		setError( "Input pieces is not connected")
		return
		
	var evaluator = GrammarEvaluator.new()
	
	var grammars = null
	if grammar_as_attribute:
		grammars = in_data.getContainerChecked( attribute_grammar, FlowData.DataType.String, self )
		if grammars == null:
			return
	else:
		var grammar = grammar
		if not evaluator.parseString( grammar ):
			for err in evaluator.getErrors():
				print( "  Error: %s" % err )
			return
			
	var symbols = in_pieces.getContainerChecked( attribute_symbol, FlowData.DataType.String, self )
	var lengths = in_pieces.getContainerChecked( attribute_length, FlowData.DataType.Float, self )
	var stream_scalables = in_pieces.getContainerChecked( attribute_scalable, FlowData.DataType.Bool, self )
	if symbols == null or lengths == null or stream_scalables == null:
		return
		
	
	# Mix the two streams in a single dictionary symbol -> length
	var pieces = {}
	var index_by_piece = {}
	var scalables = {}
	for idx : int in range( symbols.size() ):
		var symbol := StringName(symbols[idx])
		pieces[ symbol ] = lengths[idx]
		index_by_piece[ symbol ] = idx
		if stream_scalables[idx]:
			scalables[ symbol ] = true

	evaluator.setPieces( pieces )
	
		
	if trace:
		evaluator._ast.dump(0)
	
	
	for path_idx in range( path3d_nodes.size() ):
		if grammars != null:
			var grammar = grammars[path_idx]
			print( "Using grammar %s" % grammar)
			if not evaluator.parseString( grammar ):
				for err in evaluator.getErrors():
					print( "  Error: %s" % err )
				continue
			
		var path_3d = path3d_nodes[path_idx]
		var curve : Curve3D = path_3d.curve	
		var total_length : float = curve.get_baked_length()
		total_length -= curve_offset_start + curve_offset_end
	
		var generated_symbols := evaluator.sample( total_length, rng )
		
		var num_points : int = generated_symbols.size()
		var output := FlowData.Data.new()
		output.addCommonStreams( num_points )
		var spos := output.getVector3Container( FlowData.AttrPosition )
		var srot := output.getVector3Container( FlowData.AttrRotation )
		var ssize := output.getVector3Container( FlowData.AttrSize )
		
		# Get the total length covered, also acc the total covered by the 
		# scalable pieces
		var distances : PackedFloat32Array
		var acc : float = 0.0
		var acc_scalable : float = 0.0
		for symbol in generated_symbols:
			var length : float = pieces.get( symbol )
			distances.append( length )
			acc += length
			if scalables.has( symbol ):
				acc_scalable += length
		
		if trace:
			print( "Total distance covered %f / %f using %d symbols. AccScalable: %f" % [ acc, total_length, generated_symbols.size(), acc_scalable ])
		
		# If we can scale some pieces to fully cover the requested length, now it's the moment
		var scale_factor : float = 1.0
		if fit_behaviour == eFitBehaviour.Autoscale:
			if acc_scalable > 0.0 and acc < total_length:
				scale_factor = 1.0 + ( total_length - acc ) / acc_scalable

		# Places each piece along the path
		var error_length := total_length - acc
		var offset : float = curve_offset_start
		var interpiece_padding : float = 0.0
		if fit_behaviour == eFitBehaviour.AlignRight:
			offset += error_length
		elif fit_behaviour == eFitBehaviour.Centered:
			offset += ( error_length ) * 0.5
		elif fit_behaviour == eFitBehaviour.Interspace:
			interpiece_padding = error_length / float( generated_symbols.size() - 1 ) 
		
		var offsets_stream : PackedFloat32Array
		for idx in range( generated_symbols.size() ):
			var length := distances[idx]
			offsets_stream.append( offset )
			var symbol = generated_symbols[ idx ]
			if scalables.has( symbol ):
				ssize[ idx ] *= scale_factor
				length *= scale_factor
			# Spawn the piece at the middle point of the legnth
			var t : Transform3D = curve.sample_baked_with_rotation( offset + length * 0.5 )
			spos[ idx ] = path_3d.transform * t.origin
			var b : Basis = path_3d.transform.basis * t.basis
			srot[ idx ] = FlowData.basisToEuler( b )
			offset += length + interpiece_padding

		var generated_symbol_strings := PackedStringArray()
		for symbol in generated_symbols:
			generated_symbol_strings.append(String(symbol))
		output.registerStream( "symbol", generated_symbol_strings, FlowData.DataType.String )
		output.registerStream( "offset", offsets_stream, FlowData.DataType.Float )

		# For fast copy of all the streams... create a list of indices to copy based on the symbol
		var indices : PackedInt32Array
		for symbol in generated_symbols:
			indices.append( index_by_piece[ symbol ] )
			
		for key in in_pieces.streams.keys():
			if key == attribute_symbol:
				continue
			var in_stream = in_pieces.streams[ key ]
			var new_container = output.filteredStream( in_stream, indices )
			output.registerStream( key, new_container, in_stream.data_type )

		set_output( 0, output )
	
