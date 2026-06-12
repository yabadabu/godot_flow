@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Curve Remap Density",
		"settings" : CurveRemapDensityNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Remaps the density of each point in the point data to another density value according to the provided curve.\nNo curve set = identity (densities pass through). The result is clamped to 0..1.",
		"aliases" : ["Curve Remap Density"],
		"category" : "Density",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var out_data : FlowData.Data = in_data.duplicate()
	var s_density = in_data.findStream(FlowData.AttrDensity)

	var num_elems = in_data.size()
	var densities := PackedFloat32Array()
	densities.resize(num_elems)

	var in_container = s_density.container if s_density else null
	var in_size : int = in_container.size() if in_container != null else 0
	var c : Curve = settings.remap_curve
	if c == null:
		# No curve set: build an actual linear (identity) curve — an empty
		# Curve.new() samples 0 everywhere, which used to zero all densities
		c = Curve.new()
		c.add_point(Vector2(0.0, 0.0))
		c.add_point(Vector2(1.0, 1.0))

	for i in num_elems:
		var d = in_container[FlowData.bcast_idx(in_size, i)] if in_size > 0 else 1.0
		densities[i] = clampf(c.sample(d), 0.0, 1.0)

	out_data.registerStream(FlowData.AttrDensity, densities, FlowData.DataType.Float)
	set_output(0, out_data)
