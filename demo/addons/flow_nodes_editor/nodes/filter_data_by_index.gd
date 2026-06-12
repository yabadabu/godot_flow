@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Filter Data By Index",
		"settings" : FilterDataByIndexNodeSettings,
		"category" : "Filter",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Picks points matching the indices expresions. You can specify a comma-separated list of indices or slices using python syntax. " + 
					"For example:\n" +
					"  1:       # All except the first\n" +
					" -1:       # Last one\n" +
					" -2:       # Second from last\n" +
					"  :-1      # All except the last one\n" +
					"  ::2      # every second element\n" +
					"  1::2      # every second element  starting at 1\n" +
					"  0:6      # The first 6 points\n" +
					"  0:6:2    # From 0 to 6 in steps of 2\n" +
					"  1,1,2,2  # Point 1 twice and the second point twice\n"
	}

func parseSlice(expr: String, size: int, out_indices : PackedInt32Array ):
	var parts := expr.split(":", true)

	# Single index: "5", "-1"
	if parts.size() == 1:
		var i := int(parts[0])
		if i < 0:
			i = size + i
		out_indices.append( i )
		return

	var start := 0
	var end := size
	var step := 1

	if parts.size() >= 1 and parts[0] != "":
		start = int(parts[0])
	if parts.size() >= 2 and parts[1] != "":
		end = int(parts[1])
	if parts.size() >= 3 and parts[2] != "":
		step = int(parts[2])
		if step < 1:
			step = 1

	if start < 0:
		start = size + start
	if end < 0:
		end = size + end

	var i := start
	while i < end:
		out_indices.append(i)
		i += step

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
	var in_size : int = in_data.size()
	
	# This will store the indices that pass the test
	var indices_true = PackedInt32Array( )
	
	var raw_groups : PackedStringArray = settings.indices.split(",")
	for exp in raw_groups:
		var clean_exp = exp.strip_edges()
		if settings.trace:
			print( "Parsing exp %s" % [ clean_exp ])
		if clean_exp.is_empty():
			continue
		parseSlice( clean_exp, in_size, indices_true )
	set_output( 0, in_data.filter( indices_true ) )
