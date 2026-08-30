@tool
extends FlowNodeBase

@export_file var filename : String

func _init():
	meta_node = {
		"title" : "Watabou",
		"category" : "Import",
		"ins" : [],
		"outs" : [
			{ "label" : "Rooms" }, 
			{ "label" : "Doors" },
			{ "label" : "Columns" },
		],
		"tooltip" : "Imports a watabou .json exported file",
	}

func load_data( ctx : FlowData.EvaluationContext ) -> Dictionary:
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null:
		setError( ctx, "Could not open: " + filename)
		return {}
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if data == null:
		setError( ctx, "Invalid JSON: " + filename)
		return {}
	if not data is Dictionary:
		setError( ctx, "JSON root is not an object/dictionary")
		return {}
	return data

func importCoords( ctx : FlowData.EvaluationContext, in_array : Array ):
	var coords := PackedVector3Array()
	for d in in_array:
		coords.append( Vector3( d.x + 0.5, 0, d.y + 0.5 ))
	return { "coords" : coords } 

func importRects( ctx : FlowData.EvaluationContext, rects : Array ):
	var coords := PackedVector3Array()
	var sizes := PackedVector3Array()
	for r in rects:
		var w = r.w
		var h = r.h
		sizes.append( Vector3( w, 1, h ))
		coords.append( Vector3( r.x + w * 0.5, 0, r.y + h * 0.5 ))
	return { "coords" : coords, "sizes" : sizes } 

func importDoors( ctx : FlowData.EvaluationContext, doors : Array ):
	var coords := PackedVector3Array()
	var rots := PackedVector3Array()
	var types := PackedInt32Array()
	for d in doors:
		if d.dir.x == 1 and d.dir.y == 0:
			rots.append( Vector3( 0, 0, 0 ))
		elif d.dir.x == -1 and d.dir.y == 0:
			rots.append( Vector3( 180, 0, 0 ))
		elif d.dir.x == 0 and d.dir.y == 1:
			rots.append( Vector3( 90, 0, 0 ))
		else:
			rots.append( Vector3( -90, 0, 0 ))
		types.append( d.type )
		coords.append( Vector3( d.x + 0.5, 0, d.y + 0.5 ))
	return { "coords" : coords, "rots" : rots, "types" : types } 

func execute( ctx : FlowData.EvaluationContext ):
	var wd = load_data( ctx )
	if wd:
		if wd.has("rects") and typeof(wd.rects) == TYPE_ARRAY:
			var out := FlowData.Data.new()
			var rs = importRects( ctx, wd.rects )
			out.addCommonStreams( rs.coords.size() )
			out.registerStream(FlowData.AttrPosition, rs.coords)
			out.registerStream(FlowData.AttrSize, rs.sizes)
			setOutput(ctx, 0, out )
			
		if wd.has("doors") and typeof(wd.doors) == TYPE_ARRAY:
			var out := FlowData.Data.new()
			var rs = importDoors( ctx, wd.doors )
			out.addCommonStreams( rs.coords.size() )
			out.registerStream(FlowData.AttrPosition, rs.coords)
			out.registerStream(FlowData.AttrRotation, rs.rots)
			out.registerStream("door_type", rs.types)
			setOutput(ctx, 1, out )
			
		if wd.has("columns") and typeof(wd.columns) == TYPE_ARRAY:
			var out := FlowData.Data.new()
			var rs = importCoords( ctx, wd.columns )
			out.addCommonStreams( rs.coords.size() )
			out.registerStream(FlowData.AttrPosition, rs.coords)
			setOutput(ctx, 2, out )
