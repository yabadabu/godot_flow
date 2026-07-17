@tool
extends FlowNodeBase

@export var grid_size: Vector3 = Vector3.ONE * 2.0
@export var snap_position: bool = true
@export var snap_rotation: bool = false
@export var snap_scale: bool = false

func _init():
	meta_node = {
		"title" : "Snap to Grid",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Snaps point positions, rotations, or scale sizes to grid values.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if in_data == null:
		setError("Input 'In' is not connected")
		return
		
	var out_data : FlowData.Data = in_data.duplicate()
	var size = in_data.size()
	
	var grid_sz = getSettingValue(ctx, "grid_size", Vector3.ONE * 2.0)
	
	if snap_position:
		var pos = out_data.cloneStream(FlowData.AttrPosition)
		for i in range(size):
			if grid_sz.x != 0.0: pos[i].x = round(pos[i].x / grid_sz.x) * grid_sz.x
			if grid_sz.y != 0.0: pos[i].y = round(pos[i].y / grid_sz.y) * grid_sz.y
			if grid_sz.z != 0.0: pos[i].z = round(pos[i].z / grid_sz.z) * grid_sz.z
		out_data.registerStream(FlowData.AttrPosition, pos, FlowData.DataType.Vector)
		
	if snap_rotation:
		var rot = out_data.cloneStream(FlowData.AttrRotation)
		for i in range(size):
			if grid_sz.x != 0.0: rot[i].x = round(rot[i].x / grid_sz.x) * grid_sz.x
			if grid_sz.y != 0.0: rot[i].y = round(rot[i].y / grid_sz.y) * grid_sz.y
			if grid_sz.z != 0.0: rot[i].z = round(rot[i].z / grid_sz.z) * grid_sz.z
		out_data.registerStream(FlowData.AttrRotation, rot, FlowData.DataType.Vector)
		
	if snap_scale:
		var ssize = out_data.cloneStream(FlowData.AttrSize)
		for i in range(size):
			if grid_sz.x != 0.0: ssize[i].x = round(ssize[i].x / grid_sz.x) * grid_sz.x
			if grid_sz.y != 0.0: ssize[i].y = round(ssize[i].y / grid_sz.y) * grid_sz.y
			if grid_sz.z != 0.0: ssize[i].z = round(ssize[i].z / grid_sz.z) * grid_sz.z
		out_data.registerStream(FlowData.AttrSize, ssize, FlowData.DataType.Vector)
		
	set_output(0, out_data)
