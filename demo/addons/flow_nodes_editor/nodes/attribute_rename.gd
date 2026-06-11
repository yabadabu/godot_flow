@tool
extends FlowNodeBase

const AttributeRenameNodeSettings = preload("res://addons/flow_nodes_editor/nodes/attribute_rename_settings.gd")

func _init():
	meta_node = {
		"title" : "Attribute Rename",
		"settings" : AttributeRenameNodeSettings,
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Renames one attribute/stream while preserving its type and values.\nVirtual/computed streams (index, front/up/right, component accessors like name.x) can't be renamed.",
		"aliases" : ["Attribute Rename", "Rename Attribute"],
		"category" : "Metadata",
	}

func execute(_ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = require_input(0, _ctx)
	if in_data == null:
		return

	var from_name : String = settings.from_name.strip_edges()
	var to_name : String = settings.to_name.strip_edges()

	if from_name == "" or to_name == "":
		setError("Both source and destination attribute names are required")
		return

	if from_name == to_name:
		set_output(0, in_data.duplicate())
		return

	if "." in to_name or to_name == "@last" or to_name == "index" or to_name.to_lower() in ["front", "up", "right"]:
		setError("'%s' is a reserved/virtual stream name and can't be used as destination" % to_name)
		return

	var out_data : FlowData.Data = in_data.duplicate()
	# Resolve aliases like @last/Yaw to the real stream key, then require the
	# result to be a REAL stream. findStream() can also resolve synthetic
	# streams (index, front/up/right, sub-components like "pos.x") that are
	# computed on the fly and don't exist in out_data.streams — renaming those
	# used to crash on the streams[from_name] lookup below.
	from_name = out_data.translateStreamName(from_name)
	if not out_data.streams.has(from_name):
		if out_data.findStream(settings.from_name.strip_edges()) != null:
			setError("'%s' is a virtual/computed stream and can't be renamed" % settings.from_name.strip_edges())
		else:
			setError("Input does not contain attribute '%s'" % settings.from_name.strip_edges())
		return

	if from_name in [String(FlowData.AttrPosition), String(FlowData.AttrRotation), String(FlowData.AttrSize)]:
		push_warning("Attribute Rename: renaming canonical stream '%s' will break downstream transform-dependent nodes" % from_name)

	if out_data.hasStream(to_name):
		if not settings.overwrite_existing:
			setError("Destination attribute '%s' already exists" % to_name)
			return
		out_data.delStream(to_name)

	var moved_stream = out_data.streams[from_name]
	out_data.streams.erase(from_name)
	moved_stream.name = to_name
	out_data.streams[to_name] = moved_stream
	if out_data.last_added_stream_name == from_name:
		out_data.last_added_stream_name = to_name

	set_output(0, out_data)
