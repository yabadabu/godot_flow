@tool
extends FlowNodeBase

# UE PCG parity: Normal To Density — turns how well each point's surface
# normal aligns with a reference direction into a density value.

func _init():
	meta_node = {
		"title" : "Normal To Density",
		"settings" : NormalToDensityNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"aliases" : ["Normal To Density"],
		"category" : "Density",
		"tooltip" : "density = clamp(dot(normal, normal_to_compare) + offset, 0, 1) ^ strength,\ncombined with the existing density per density_mode. Uses the 'normal' stream,\nfalling back to each point's up vector derived from its rotation.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var out_data : FlowData.Data = in_data.duplicate()
	var num_points := in_data.size()
	if num_points == 0:
		set_output(0, out_data)
		return

	# Normal source: AttrNormal stream, else up vector from the rotation stream.
	var normal_stream = in_data.findStream(FlowData.AttrNormal)
	if normal_stream != null and (normal_stream.data_type != FlowData.DataType.Vector or normal_stream.container.size() == 0):
		normal_stream = null
	var rot_stream = null
	if normal_stream == null:
		rot_stream = in_data.findStream(FlowData.AttrRotation)
		if rot_stream != null and (rot_stream.data_type != FlowData.DataType.Vector or rot_stream.container.size() == 0):
			rot_stream = null
		if rot_stream == null:
			setError("Input has neither a 'normal' nor a 'rotation' stream")
			return

	# Existing density (missing stream = constant 1.0).
	var density_stream = in_data.findStream(FlowData.AttrDensity)
	if density_stream != null and (density_stream.data_type != FlowData.DataType.Float or density_stream.container.size() == 0):
		density_stream = null

	var compare : Vector3 = getSettingValue(ctx, "normal_to_compare", Vector3.UP)
	compare = compare.normalized()
	if compare.length_squared() == 0.0:
		compare = Vector3.UP
	var offset : float = getSettingValue(ctx, "offset", 0.0)
	var strength : float = getSettingValue(ctx, "strength", 1.0)
	var density_mode : int = settings.density_mode

	var densities := PackedFloat32Array()
	densities.resize(num_points)

	for i in range(num_points):
		var normal : Vector3
		if normal_stream != null:
			normal = normal_stream.container[FlowData.bcast_idx(normal_stream.container.size(), i)]
		else:
			var euler : Vector3 = rot_stream.container[FlowData.bcast_idx(rot_stream.container.size(), i)]
			normal = FlowData.eulerToBasis(euler).y
		normal = normal.normalized()

		var value := pow(clampf(normal.dot(compare) + offset, 0.0, 1.0), strength)

		var current := 1.0
		if density_stream != null:
			current = density_stream.container[FlowData.bcast_idx(density_stream.container.size(), i)]

		var result : float
		match density_mode:
			NormalToDensityNodeSettings.eDensityMode.Minimum:
				result = minf(current, value)
			NormalToDensityNodeSettings.eDensityMode.Maximum:
				result = maxf(current, value)
			NormalToDensityNodeSettings.eDensityMode.Add:
				result = current + value
			NormalToDensityNodeSettings.eDensityMode.Multiply:
				result = current * value
			_: # Set
				result = value
		densities[i] = clampf(result, 0.0, 1.0)

	out_data.registerStream(FlowData.AttrDensity, densities, FlowData.DataType.Float)
	set_output(0, out_data)
