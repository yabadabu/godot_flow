@tool
extends FlowNodeBase

@export_file var filename : String

func _init():
	meta_node = {
		"title" : "Watabou Dwelling",
		"category" : "Import",
		"ins" : [],
		"outs" : [
			{ "label" : "Floors" }, 
			{ "label" : "Doors" }, 
			{ "label" : "Windows" }, 
			{ "label" : "Stairs" }, 
		],
		"tooltip" : "Imports a watabou dwelling exported in .json format",
	}

func load_data( ctx : FlowData.EvaluationContext, infilename : String ) -> Dictionary:
	if infilename.strip_edges().is_empty():
		setError( ctx, "Missing filename")
		return {}
	var file := FileAccess.open(infilename, FileAccess.READ)
	if file == null:
		setError( ctx, "Could not open: " + infilename)
		return {}
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if data == null:
		setError( ctx, "Invalid JSON: " + infilename)
		return {}
	if not data is Dictionary:
		setError( ctx, "JSON root is not an object/dictionary")
		return {}
	return data

func importRooms( rooms : Array, floor_level : int ):
	var room_names := PackedStringArray()
	var coords := PackedVector3Array()
	for room in rooms:
		for cell in room.cells:
			coords.append( readCell( cell, floor_level ))
			room_names.append( room.name )
	return { "coords" : coords, "room_name" : room_names }

func importDoors( doors : Array, floor_level : int ):
	var coords := PackedVector3Array()
	var rots := PackedVector3Array()
	for door in doors:
		readEdge( door.edge, floor_level, coords, rots )
	return { "coords" : coords, "rots" : rots }
	
func importWindows( windows : Array, floor_level : int ):
	var coords := PackedVector3Array()
	var rots := PackedVector3Array()
	for window in windows:
		readEdge( window, floor_level, coords, rots )
	return { "coords" : coords, "rots" : rots }
	
func importStairs( stairs : Array, floor_level : int ):
	var coords := PackedVector3Array()
	var rots := PackedVector3Array()
	var ups := PackedByteArray()
	for stair in stairs:
		readEdge( stair, floor_level, coords, rots )
		# Read again wihout the position correction
		coords[ coords.size() - 1 ] = readCell( stair.cell, floor_level )
		ups.append( 1 if stair.up else 0 )
	return { "coords" : coords, "rots" : rots, "ups" : ups }
	
func importStream( ctx : FlowData.EvaluationContext, wd : Dictionary, floor_level : int, out_idx : int, container_name : String, importer : Callable ) -> bool:
	if wd.has(container_name):
		var container = wd.get(container_name)
		if typeof( container ) == TYPE_ARRAY:
			var out := FlowData.Data.new()
			var rs = importer.call( container, floor_level )
			out.addCommonStreams( rs.coords.size() )
			out.registerStream(FlowData.AttrPosition, rs.coords)
			if rs.has( "rots" ):
				out.registerStream(FlowData.AttrRotation, rs.rots)
			if rs.has( "room_name" ):
				out.registerStream("room_name", rs.room_name)
			if rs.has( "ups" ):
				out.registerStream("ups", rs.ups)
			setOutput(ctx, out_idx, out )
			return true
	setError( ctx, "Failed to find stream %s" % container_name )
	return false

func readCell( cell : Dictionary, floor_level : int ):
	return Vector3(-cell.i, floor_level, cell.j)

func readEdge( edge : Dictionary, floor_level : int, coords : PackedVector3Array, rots : PackedVector3Array ):
	var coord = readCell( edge.cell, floor_level )
	if edge.dir == "w":
		coord.z -= 0.5
		rots.append( Vector3( 0,-90,0) )
	elif edge.dir == "e":
		coord.z += 0.5
		rots.append( Vector3( 0,90,0) )
	elif edge.dir == "n":
		coord.x += 0.5
		rots.append( Vector3( 0,180,0) )
	elif edge.dir == "s":
		coord.x -= 0.5
		rots.append( Vector3( 0,0,0) )
	coords.append( coord )	

func execute( ctx : FlowData.EvaluationContext ):
	var wd = load_data( ctx, filename )
	if wd:
		var floors = wd.floors
		for floor in floors:
			var floor_level : float = float(floor.level)
			importStream( ctx, floor, floor_level, 0, "rooms", importRooms )
			importStream( ctx, floor, floor_level, 1, "doors", importDoors )
			importStream( ctx, floor, floor_level, 2, "windows", importWindows )
			importStream( ctx, floor, floor_level, 3, "stairs", importStairs )
		
		# Import the main entrance
		# I need a fake bulk in stream 0
		setOutput(ctx, 0, FlowData.Data.new() )
		# Convert the root dict into an fake array or 1 item, parse it as a Window
		wd.exit = [ wd.exit ]
		importStream( ctx, wd, 0, 1, "exit", importWindows )
