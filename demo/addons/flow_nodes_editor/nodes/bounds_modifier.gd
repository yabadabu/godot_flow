@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Bounds Modifier",
		"settings" : BoundsModifierNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Modifies the size/bounds property on points in the provided point data.\nOnly the per-axis extent |max - min| is applied — the bounds center is ignored\n(point positions are unchanged, unlike UE which preserves min/max relative to the point).",
		"aliases" : ["Bounds Modifier"],
		"category" : "Spatial",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		return

	var out_data : FlowData.Data = in_data.duplicate()
	if not out_data.hasStream(FlowData.AttrSize):
		if Engine.is_editor_hint() and ctx.owner == null:
			set_output(0, FlowData.Data.new())
			return
		setError("Input must provide a size stream")
		return
	var ssizes = out_data.cloneStream(FlowData.AttrSize)
	if ssizes == null:
		if Engine.is_editor_hint() and ctx.owner == null:
			set_output(0, FlowData.Data.new())
			return
		setError("Input must provide a size stream")
		return

	var mode = settings.mode
	var b_min = settings.bounds_min
	var b_max = settings.bounds_max
	var size_val = (b_max - b_min).abs()

	for i in ssizes.size():
		if mode == BoundsModifierNodeSettings.eMode.Set:
			ssizes[i] = size_val
		elif mode == BoundsModifierNodeSettings.eMode.Add:
			ssizes[i] += size_val
		elif mode == BoundsModifierNodeSettings.eMode.Multiply:
			ssizes[i] = ssizes[i] * size_val

	var err = out_data.registerStream(FlowData.AttrSize, ssizes, FlowData.DataType.Vector)
	if err:
		setError(err)
		return
	set_output(0, out_data)
