@tool
extends FlowNodeBase

@export var out_name : String = "color"
@export var use_palette : bool = true:
	set(value):
		if use_palette != value:
			use_palette = value
			notify_property_list_changed()

@export var palette : Array[Color] = [
	Color(1.0, 0.078, 0.576, 1.0), # Fall Guys Pink
	Color(0.0, 0.749, 1.0, 1.0),   # Fall Guys Cyan
	Color(1.0, 0.843, 0.0, 1.0)    # Fall Guys Yellow
]

@export_range(0.0, 1.0) var hue_center : float = 0.0
@export_range(0.0, 1.0) var hue_width  : float = 1.0
@export_range(0.0, 1.0) var sat_min : float = 0.6
@export_range(0.0, 1.0) var sat_max : float = 1.0
@export_range(0.0, 1.0) var val_min : float = 0.6
@export_range(0.0, 1.0) var val_max : float = 1.0

func _init():
	meta_node = {
		"title" : "Random Color",
		"category" : "Metadata",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates random colors for each point.",
	}

func exposeParam( name : String ) -> bool:
	if name == "out_name" or name == "use_palette":
		return true
	if use_palette:
		return name == "palette"
	return name != "palette"

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if not in_data:
		setError("Input is invalid")
		return
	var out_data : FlowData.Data = in_data.duplicate()
	var in_size = in_data.size()
	
	var colors = PackedColorArray()
	colors.resize(in_size)
	
	if use_palette:
		var palette : Array[Color] = palette
		var palette_size : int = palette.size()
		for i in range(in_size):
			var idx = rng.randi_range(0, palette_size - 1)
			colors[i] = palette[idx]
	else:
		var h_center : float = hue_center
		var h_width : float = hue_width
		var s_min : float= sat_min
		var s_max : float= sat_max
		var v_min : float= val_min
		var v_max : float= val_max
		for i in range(in_size):
			# Hue needs to wrap
			var h = fposmod( h_center + rng.randf_range(-h_width, h_width), 1.0)
			var s = rng.randf_range(s_min, s_max)
			var v = rng.randf_range(v_min, v_max)
			colors[i] = Color.from_hsv(h, s, v, 1.0)
		
	var err = out_data.registerStream(out_name, colors)
	if err:
		setError(err)
		return
		
	set_output(0, out_data)
