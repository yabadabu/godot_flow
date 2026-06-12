@tool
extends FlowNodeBase

const RandomColorNodeSettings = preload("res://addons/flow_nodes_editor/nodes/random_color_settings.gd")

func _init():
	meta_node = {
		"title" : "Random Color",
		"settings" : RandomColorNodeSettings,
		"category" : "Metadata",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates random colors for each point.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if not in_data:
		setError("Input is invalid")
		return
	var out_data : FlowData.Data = in_data.duplicate()
	var in_size = in_data.size()
	
	var colors = PackedColorArray()
	colors.resize(in_size)
	
	if settings.use_palette:
		var palette : Array[Color] = settings.palette
		var palette_size : int = palette.size()
		for i in range(in_size):
			var idx = rng.randi_range(0, palette_size - 1)
			colors[i] = palette[idx]
	else:
		var h_center : float = settings.hue_center
		var h_width : float = settings.hue_width
		var s_min : float= settings.sat_min
		var s_max : float= settings.sat_max
		var v_min : float= settings.val_min
		var v_max : float= settings.val_max
		for i in range(in_size):
			# Hue needs to wrap
			var h = fposmod( h_center + rng.randf_range(-h_width, h_width), 1.0)
			var s = rng.randf_range(s_min, s_max)
			var v = rng.randf_range(v_min, v_max)
			colors[i] = Color.from_hsv(h, s, v, 1.0)
		
	var err = out_data.registerStream(settings.out_name, colors)
	if err:
		setError(err)
		return
		
	set_output(0, out_data)
