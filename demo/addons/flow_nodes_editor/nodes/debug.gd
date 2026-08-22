@tool
extends FlowNodeBase

enum eOperation {
	AsDefaultDebugDraw,
	AsText,
	AsVectorLine,
	AsLineTo,
	AsAxis,
}

@export var operation : eOperation = eOperation.AsDefaultDebugDraw:
	set(value):
		if operation != value:
			operation = value
			notify_property_list_changed()

@export var attribute_name: String = ""
@export var color : Color = Color.WHITE
@export var scale : float = 1.0
var offset := Vector2(0.0, 0.0)

func _init():
	meta_node = {
		"title" : "Debug",
		"category" : "Debug",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"is_final" : true,
		"tooltip" : "Forces the visualization of the debug node. Used when some specific values are required in the debug options.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data = getInput(ctx,  0 )
	setOutput(ctx, 0, in_data)

	if operation == eOperation.AsDefaultDebugDraw:
		debug_enabled = true
		return

	var stream
	var data
	if operation == eOperation.AsAxis:
		# There are not so many attributes of type transform, it's more common
		# to tweak between boxes to transform and not caring about the current attribute value
		stream = in_data.getTransformsStream(attribute_name)
		if not stream:
			stream = in_data.getTransformsStream()
		if not stream:
			return
	else:
		var attr_name = attribute_name.strip_escapes()
		if not attr_name:
			return
		stream = in_data.findStream(attr_name)
		if not stream:
			return
		data = stream.container

	var in_pos_stream = in_data.findStream( FlowData.AttrPosition )
	if not in_pos_stream:
		return
	var in_positions : PackedVector3Array = in_pos_stream.container
	var entry_count := in_positions.size()
	if operation == eOperation.AsAxis:
		entry_count = mini(entry_count, stream.eulers.size())
	else:
		entry_count = mini(entry_count, data.size())

	if operation == eOperation.AsText:
		var font_size = 14 * scale
		if stream.data_type == FlowData.DataType.Float:
			for idx in range(entry_count):
				ctx.debugText(in_positions[idx], "%1.3f" % data[idx], color, offset, font_size)
		elif stream.data_type == FlowData.DataType.Vector:
			for idx in range(entry_count):
				ctx.debugText(in_positions[idx], "%1.2f, %1.2f, %1.2f" % [data[idx].x, data[idx].y, data[idx].z], color, offset, font_size)
		else:
			for idx in range(entry_count):
				ctx.debugText(in_positions[idx], "%s" % data[idx], color, offset, font_size)

	elif operation == eOperation.AsVectorLine:
		if stream.data_type == FlowData.DataType.Vector:
			for idx in range(entry_count):
				ctx.debugLine(in_positions[idx], in_positions[idx] + data[idx] * scale, color, 1.0)
		else:
			setError(ctx, "Attribute %s is not a Vector" % attribute_name)

	elif operation == eOperation.AsLineTo:
		if stream.data_type == FlowData.DataType.Vector:
			for idx in range(entry_count):
				ctx.debugLine(in_positions[idx], data[idx], color, 1.0)
		else:
			setError(ctx, "Attribute %s is not a Vector" % attribute_name)

	elif operation == eOperation.AsAxis:
		var eulers = stream.eulers
		for idx in range(entry_count):
			var p0 : = in_positions[idx]
			var basis := Basis.from_euler( eulers[idx] * PI / 180.0 )
			ctx.debugLine(p0, p0 + basis.x * scale, Color.RED, 1.0)
			ctx.debugLine(p0, p0 + basis.y * scale, Color.GREEN, 1.0)
			ctx.debugLine(p0, p0 - basis.z * scale, Color.BLUE, 1.0)
