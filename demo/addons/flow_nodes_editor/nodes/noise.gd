@tool
extends FlowNodeBase
@export var out_name : String = "density"
@export var in_scale : float = 1.0
@export var noise_bias : float = 0.0
@export var noise_amplitude : float = 1.0
@export var sample_attribute : String = "position"

enum eOutputType {
	Float = 0,
	Vector3 = 1,
}
enum eOutputRange {
	ZeroToOne = 0,
	MinusOneToOne = 1,
}

enum eMode {
	Override = 0,
	Add = 1,
}

enum eSampleSpace {
	World3D = 0,
	XZ2D = 1,
}

enum eNoiseType {
	Value = 0,
	ValueCubic = 1,
	Perlin = 2,
	Cellular = 3,
	Simplex = 4,
	SimplexSmooth = 5,
}

enum eFractalType {
	None = 0,
	FBM = 1,
	Ridged = 2,
	PingPong = 3,
}
@export var output_range : eOutputRange = eOutputRange.MinusOneToOne
@export var output_type : eOutputType = eOutputType.Float
@export var mode : eMode = eMode.Override
@export var sample_space : eSampleSpace = eSampleSpace.World3D
@export var noise_type : eNoiseType = eNoiseType.Value
@export var fractal_type : eFractalType = eFractalType.None:
	set(value):
		value = clampi(value, 0, eFractalType.size() - 1)
		if fractal_type != value:
			fractal_type = value
			notify_property_list_changed()
@export var fractal_octaves : int = 4
@export var fractal_lacunarity : float = 2.0
@export var fractal_gain : float = 0.5
@export var fractal_ping_pong_strength : float = 2.0


func _init():
	meta_node = {
		"title" : "Noise",
		"category" : "Spatial",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Outputs an attribute with Noise values",
	}

func exposeParam(name : String) -> bool:
	if name == "fractal_octaves" or name == "fractal_lacunarity" or name == "fractal_gain" or name == "fractal_ping_pong_strength":
		return fractal_type != eFractalType.None
	return true

func _get_attribute_selector_props() -> Array[Dictionary]:
	return [
		{ "prop": "sample_attribute", "port": 0 },
	]

func _map_noise_type() -> int:
	match noise_type:
		eNoiseType.ValueCubic:
			return FastNoiseLite.NoiseType.TYPE_VALUE
		eNoiseType.Perlin:
			return FastNoiseLite.NoiseType.TYPE_PERLIN
		eNoiseType.Cellular:
			return FastNoiseLite.NoiseType.TYPE_CELLULAR
		eNoiseType.Simplex:
			return FastNoiseLite.NoiseType.TYPE_SIMPLEX
		eNoiseType.SimplexSmooth:
			return FastNoiseLite.NoiseType.TYPE_SIMPLEX
		_:
			return FastNoiseLite.NoiseType.TYPE_VALUE

func _map_fractal_type() -> int:
	match fractal_type:
		eFractalType.FBM:
			return FastNoiseLite.FractalType.FRACTAL_FBM
		eFractalType.Ridged:
			return FastNoiseLite.FractalType.FRACTAL_RIDGED
		eFractalType.PingPong:
			return FastNoiseLite.FractalType.FRACTAL_PING_PONG
		_:
			return FastNoiseLite.FractalType.FRACTAL_NONE

func _resolve_sample_positions(in_data : FlowData.Data) -> PackedVector3Array:
	var sample_name = sample_attribute.strip_edges()
	if sample_name == "":
		sample_name = FlowData.AttrPosition
	var sample_stream = in_data.findStream(sample_name)
	if sample_stream and sample_stream.data_type == FlowData.DataType.Vector:
		var size = in_data.size()
		var stream_size = sample_stream.container.size()
		var values : PackedVector3Array = sample_stream.container
		if stream_size == size:
			return values
		if stream_size == 1 and size > 0:
			var expanded := PackedVector3Array()
			expanded.resize(size)
			for i in range(size):
				expanded[i] = values[0]
			return expanded
	return in_data.getVector3Container(FlowData.AttrPosition)

func _sample_noise(noise : FastNoiseLite, p : Vector3) -> float:
	var nval : float = noise.get_noise_2d(p.x, p.z) if sample_space == eSampleSpace.XZ2D else noise.get_noise_3d(p.x, p.y, p.z)
	nval = clampf(nval,-1.0,1.0)
	if output_range == eOutputRange.ZeroToOne:
		return ( nval + 1.0 ) * 0.5
	return nval
	
func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	if in_data == null:
		setError(ctx, "Input not found")
		return

	var out_data : FlowData.Data = in_data.duplicate()

	var ipos : PackedVector3Array = _resolve_sample_positions(in_data)
	if ipos.size() != in_data.size():
		setError(ctx, "Noise source attribute '%s' must be a Vector stream with %d values (or 1 for broadcast)" % [sample_attribute, in_data.size()])
		return
		
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.noise_type = _map_noise_type()
	noise.fractal_type = _map_fractal_type()
	noise.fractal_octaves = maxi(1, fractal_octaves)
	noise.fractal_lacunarity = fractal_lacunarity
	noise.fractal_gain = fractal_gain
	noise.fractal_ping_pong_strength = fractal_ping_pong_strength
	
	var in_scale : float = in_scale
	var noise_bias : float = noise_bias
	var noise_amplitude : float = noise_amplitude
	
	var in_size := in_data.size()
	
	var target_exists := false
	var existing_stream = out_data.findStream(out_name)
	if existing_stream != null and mode == eMode.Add:
		target_exists = true

	var out_container
	
	if output_type == eOutputType.Vector3:
		var sout_generated := PackedVector3Array()
		sout_generated.resize(in_size)
		for i in range(in_size):
			var pos := ipos[i] * in_scale
			var raw_x := _sample_noise(noise, pos)
			var raw_y := _sample_noise(noise, pos + Vector3(100.0, 100.0, 100.0))
			var raw_z := _sample_noise(noise, pos + Vector3(200.0, 200.0, 200.0))
			
			var val_x := noise_bias + raw_x * noise_amplitude
			var val_y := noise_bias + raw_y * noise_amplitude
			var val_z := noise_bias + raw_z * noise_amplitude
			
			sout_generated[i] = Vector3(val_x, val_y, val_z)
			
		if target_exists:
			var existing_container = existing_stream.container
			if existing_stream.data_type == FlowData.DataType.Vector:
				var out_vec := PackedVector3Array()
				out_vec.resize(in_size)
				for i in range(in_size):
					out_vec[i] = existing_container[i] + sout_generated[i]
				out_container = out_vec
			elif existing_stream.data_type == FlowData.DataType.Float:
				var out_vec := PackedVector3Array()
				out_vec.resize(in_size)
				for i in range(in_size):
					out_vec[i] = Vector3(existing_container[i], existing_container[i], existing_container[i]) + sout_generated[i]
				out_container = out_vec
			else:
				out_container = sout_generated
		else:
			out_container = sout_generated
	else:
		var sout_generated := PackedFloat32Array()
		sout_generated.resize(in_size)
		for i in range(in_size):
			var pos := ipos[i] * in_scale
			var raw_noise := _sample_noise(noise, pos)
			sout_generated[i] = noise_bias + raw_noise * noise_amplitude
			
		if target_exists:
			var existing_container = existing_stream.container
			if existing_stream.data_type == FlowData.DataType.Float:
				var out_floats := PackedFloat32Array()
				out_floats.resize(in_size)
				for i in range(in_size):
					out_floats[i] = existing_container[i] + sout_generated[i]
				out_container = out_floats
			elif existing_stream.data_type == FlowData.DataType.Vector:
				var out_vec := PackedVector3Array()
				out_vec.resize(in_size)
				for i in range(in_size):
					out_vec[i] = existing_container[i] + Vector3(sout_generated[i], sout_generated[i], sout_generated[i])
				out_container = out_vec
			else:
				out_container = sout_generated
		else:
			out_container = sout_generated
			
	var err = out_data.registerStream(out_name, out_container)
	if err:
		setError(ctx, err)
		return
		
	setOutput(ctx, 0, out_data)
