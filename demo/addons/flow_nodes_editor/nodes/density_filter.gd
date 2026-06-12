@tool
extends "res://addons/flow_nodes_editor/nodes/attribute_filter_range.gd"

# UE PCG parity: Density Filter — splits points by their density value.
# Composes the Attribute Filter Range implementation (hardwired to the
# density stream via DensityFilterNodeSettings) instead of copying it.

func _init():
	meta_node = {
		"title" : "Density Filter",
		"settings" : DensityFilterNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "In Filter" }, { "label" : "Outside Filter" }],
		"aliases" : ["Density Filter"],
		"category" : "Filter",
		"tooltip" : "Keeps points whose density falls inside [lower_bound, upper_bound] on 'In Filter',\nthe rest on 'Outside Filter'. Points without a density stream count as density 1.0.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, ctx, "Input 'In'")
	if in_data == null:
		# Editor preview: require_input emitted an empty Data on port 0 — mirror it on port 1.
		if num_generated_bulks > 0 and generated_bulks[num_generated_bulks - 1].size() == 1:
			set_output(1, FlowData.Data.new())
		return

	# Missing density stream = every point has density 1.0 (UE parity).
	var work : FlowData.Data = in_data
	if in_data.size() > 0 and in_data.findStream(FlowData.AttrDensity) == null:
		work = in_data.duplicate()
		var densities := PackedFloat32Array()
		densities.resize(work.size())
		densities.fill(1.0)
		work.registerStream(FlowData.AttrDensity, densities, FlowData.DataType.Float)
	inputs[0] = work

	var bulks_before := num_generated_bulks
	super.execute(ctx)

	# invert_filter swaps which pin receives the in-range points.
	if settings.invert_filter and num_generated_bulks > bulks_before:
		var bulk : Array = generated_bulks[num_generated_bulks - 1]
		if bulk.size() >= 2:
			var tmp = bulk[0]
			bulk[0] = bulk[1]
			bulk[1] = tmp
