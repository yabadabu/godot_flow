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
			{ "label" : "Water" },
			{ "label" : "Notes" },
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

func importCoords( in_array : Array ):
	var coords := PackedVector3Array()
	for d in in_array:
		coords.append( Vector3( d.x + 0.5, 0, d.y + 0.5 ))
	return { "coords" : coords } 

func importRects( rects : Array ):
	var coords := PackedVector3Array()
	var sizes := PackedVector3Array()
	for r in rects:
		var w = r.w
		var h = r.h
		sizes.append( Vector3( w, 1, h ))
		coords.append( Vector3( r.x + w * 0.5, 0, r.y + h * 0.5 ))
	return { "coords" : coords, "sizes" : sizes } 

func importNotes( data : Array ):
	var coords := PackedVector3Array()
	var refs := PackedInt32Array()
	var notes := PackedStringArray()
	for d in data:
		notes.append( d.text )
		refs.append( int(d.ref) )
		coords.append( Vector3( d.pos.x + 0.5, 0, d.pos.y + 0.5 ))
	return { "coords" : coords, "notes" : notes } 

func importDoors( doors : Array ):
	var coords := PackedVector3Array()
	var rots := PackedVector3Array()
	var types := PackedInt32Array()
	for d in doors:
		if d.dir.x == 1 and d.dir.y == 0:
			rots.append( Vector3( 0, 0, 0 ))
		elif d.dir.x == -1 and d.dir.y == 0:
			rots.append( Vector3( 0, 0, 0 ))
		elif d.dir.x == 0 and d.dir.y == 1:
			rots.append( Vector3( 0, 90, 0 ))
		else:
			rots.append( Vector3( 0, -90, 0 ))
		types.append( d.type )
		coords.append( Vector3( d.x + 0.5, 0, d.y + 0.5 ))
	return { "coords" : coords, "rots" : rots, "door_type" : types } 

func importStream( ctx : FlowData.EvaluationContext, wd : Dictionary, out_idx : int, container_name : String, importer : Callable ) -> bool:
	if wd.has(container_name):
		var container = wd.get(container_name)
		if typeof( container ) == TYPE_ARRAY:
			var out := FlowData.Data.new()
			var rs = importer.call( container )
			out.addCommonStreams( rs.coords.size() )
			out.registerStream(FlowData.AttrPosition, rs.coords)
			if rs.has( "sizes" ):
				out.registerStream(FlowData.AttrSize, rs.sizes)
			if rs.has( "rots" ):
				out.registerStream(FlowData.AttrRotation, rs.rots)
			if rs.has( "door_type" ):
				out.registerStream("door_type", rs.door_type)
			if rs.has( "ref" ):
				out.registerStream("ref", rs.ref)
			if rs.has( "notes" ):
				out.registerStream("notes", rs.notes)
			setOutput(ctx, out_idx, out )
		return true
	return false

func execute( ctx : FlowData.EvaluationContext ):
	var wd = load_data( ctx )
	if wd:
		importStream( ctx, wd, 0, "rects", importRects )
		importStream( ctx, wd, 1, "doors", importDoors )
		importStream( ctx, wd, 2, "columns", importCoords )
		importStream( ctx, wd, 3, "water", importCoords )
		importStream( ctx, wd, 4, "notes", importNotes )
