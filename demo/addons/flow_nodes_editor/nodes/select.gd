@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Select",
		"settings" : SelectNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Filter inputs by the ratio.\nSo when ratio = 0.2, only 20% of the input points will appear in the output (picked randomly).",
	}

# Efraimidis–Spirakis
static func weighted_sample_without_replacement(weights: PackedFloat32Array, k: int, seed: int = 0) -> PackedInt32Array:
	var n := weights.size()
	k = clamp(k, 0, n)
	var out := PackedInt32Array()
	if n == 0 or k == 0:
		return out

	var rng := RandomNumberGenerator.new()
	if seed != 0: rng.seed = seed

	# keys[i] = -ln(u)/w_i (INF for w<=0)
	var keys := PackedFloat32Array()
	keys.resize(n)
	var all_zero := true
	for i in n:
		var w := weights[i]
		if w > 0.0:
			all_zero = false
			var u := rng.randf_range(1e-12, 1.0)
			keys[i] = -log(u) / w
		else:
			keys[i] = INF

	# Uniform fallback if all weights are zero
	if all_zero:
		var idx := PackedInt32Array()
		idx.resize(n)
		for i in n: idx[i] = i
		# Fisher–Yates
		for i in range(n - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := idx[i]; idx[i] = idx[j]; idx[j] = tmp
		out.resize(k)
		for t in k: out[t] = idx[t]
		return out

	# Indices 0..n-1, sort by keys ascending
	var idx_arr: Array = []
	idx_arr.resize(n)
	for i in n: idx_arr[i] = i
	idx_arr.sort_custom(func(a, b): return keys[int(a)] < keys[int(b)])

	out.resize(k)
	for t in k: out[t] = int(idx_arr[t])
	return out


func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	#in_data.dump( "Select.Input")
	var in_size = in_data.size()
	
	var attr_name = getSettingValue( ctx, "weight_name")
	var ratio = getSettingValue(ctx, "ratio")
	ratio = clamp( ratio, 0.0, 1.0 )
	
	var out_size = round(in_size * ratio)
	#print( "Select: From %d, took %1.2f%% -> %d" % [ in_size, settings.ratio, out_size ])
	
	var indices : PackedInt32Array
	if attr_name:
		var weight_stream = in_data.findStream( attr_name )
		if weight_stream == null:
			setError( "Input Weight Name %s not found" % [attr_name])
			return
		indices = weighted_sample_without_replacement( weight_stream.container, out_size, settings.random_seed )
	else:
			
		var pool := range(in_size)
		shuffleArray( pool )
		indices = PackedInt32Array( pool )
		var subset := indices.slice(0, out_size)
		subset.sort()
		indices = subset
	
	var out_data = in_data.filter( indices )
	set_output( 0, out_data )
