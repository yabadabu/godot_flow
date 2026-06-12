@tool
extends FlowNodeBase

const SnapToGridNodeSettings = preload("res://addons/flow_nodes_editor/nodes/snap_to_grid_settings.gd")

func _init():
	meta_node = {
		"title" : "Snap to Grid",
		"settings" : SnapToGridNodeSettings,
		"aliases" : ["Snap To Grid", "Quantize Transform"],
		"category" : "Spatial",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Snaps point positions, rotations, or scale sizes to grid values.\nRotation snapping operates on Euler DEGREES.\nRotation/scale can use their own steps; when left at zero they fall back to grid_size.\nAxes with a step of 0 are left untouched.",
	}

func _snap_stream( stream : PackedVector3Array, step : Vector3 ):
	for i in range(stream.size()):
		if step.x != 0.0: stream[i].x = round(stream[i].x / step.x) * step.x
		if step.y != 0.0: stream[i].y = round(stream[i].y / step.y) * step.y
		if step.z != 0.0: stream[i].z = round(stream[i].z / step.z) * step.z

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input( 0, ctx, "Input 'In'" )
	if in_data == null:
		return

	var out_data : FlowData.Data = in_data.duplicate()

	var grid_sz : Vector3 = getSettingValue(ctx, "grid_size", Vector3.ONE * 2.0)
	var rot_grid : Vector3 = getSettingValue(ctx, "rotation_grid_size", Vector3.ZERO)
	var scale_grid : Vector3 = getSettingValue(ctx, "scale_grid_size", Vector3.ZERO)
	if rot_grid == Vector3.ZERO:
		rot_grid = grid_sz
	if scale_grid == Vector3.ZERO:
		scale_grid = grid_sz

	if settings.snap_position:
		var pos = out_data.cloneStream(FlowData.AttrPosition)
		if pos == null:
			setError("Input has no %s stream" % FlowData.AttrPosition)
			return
		_snap_stream(pos, grid_sz)
		out_data.registerStream(FlowData.AttrPosition, pos, FlowData.DataType.Vector)

	if settings.snap_rotation:
		var rot = out_data.cloneStream(FlowData.AttrRotation)
		if rot == null:
			setError("Input has no %s stream" % FlowData.AttrRotation)
			return
		_snap_stream(rot, rot_grid)
		out_data.registerStream(FlowData.AttrRotation, rot, FlowData.DataType.Vector)

	if settings.snap_scale:
		var ssize = out_data.cloneStream(FlowData.AttrSize)
		if ssize == null:
			setError("Input has no %s stream" % FlowData.AttrSize)
			return
		_snap_stream(ssize, scale_grid)
		out_data.registerStream(FlowData.AttrSize, ssize, FlowData.DataType.Vector)

	set_output(0, out_data)
