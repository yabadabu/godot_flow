@tool
extends FlowNodeBase

@export_file var filename : String

var curr_level : int = 0

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

func importRooms( rooms : Array, out : Dictionary ):
	for room in rooms:
		for cell in room.cells:
			out.coords.append( readCell( cell ))
			out.room_names.append( room.get( "name", "" ) )

func importDoors( doors : Array, out : Dictionary ):
	for door in doors:
		readEdge( door.edge, out.coords, out.rots )
	
func importWindows( windows : Array, out : Dictionary ):
	for window in windows:
		readEdge( window, out.coords, out.rots )
	
func importStairs( stairs : Array, out : Dictionary ):
	for stair in stairs:
		readEdge( stair, out.contact_pos, out.rots )
		# Read again wihout the position correction
		out.coords.append( readCell( stair.cell ) )
		out.ups.append( 1 if stair.up else 0 )
	
func importStream( ctx : FlowData.EvaluationContext, wd : Dictionary, out : Dictionary, container_name : String, importer : Callable ) -> bool:
	if wd.has(container_name):
		var items = wd.get(container_name)
		if typeof( items ) == TYPE_ARRAY:
			var rs = importer.call( items, out )
			return true
	setError( ctx, "Failed to find stream %s" % container_name )
	return false

func readCell( cell : Dictionary ):
	return Vector3(-cell.i, curr_level, cell.j)

func readEdge( edge : Dictionary, coords : PackedVector3Array, rots : PackedVector3Array ):
	var coord = readCell( edge.cell )
	if edge.dir == "w":
		coord.z -= 0.5
		rots.append( Vector3( 0,0,0) )
	elif edge.dir == "e":
		coord.z += 0.5
		rots.append( Vector3( 0,180,0) )
	elif edge.dir == "n":
		coord.x += 0.5
		rots.append( Vector3( 0,90,0) )
	elif edge.dir == "s":
		coord.x -= 0.5
		rots.append( Vector3( 0,-90,0) )
	coords.append( coord )	

func newEmptyData() -> Dictionary:
	var d := Dictionary()
	d.coords = PackedVector3Array()
	return d

func outputStream( ctx : FlowData.EvaluationContext, port_idx : int, data : Dictionary ):
	var d = FlowData.Data.new()
	d.addCommonStreams( data.coords.size() )
	d.registerStream( FlowData.AttrPosition, data.coords )
	if data.has( "room_names" ):
		d.registerStream( "room_name", data.room_names )
	if data.has( "rots" ):
		d.registerStream( FlowData.AttrRotation, data.rots )
	if data.has( "contact_pos" ):
		d.registerStream( "contact_pos", data.contact_pos )
	if data.has( "ups" ):
		d.registerStream( "ups", data.ups )
	setOutput( ctx, port_idx, d )

func execute( ctx : FlowData.EvaluationContext ):
	
	var floors := newEmptyData()
	floors.room_names = PackedStringArray()
	var doors := newEmptyData()
	doors.rots = PackedVector3Array()
	var windows := newEmptyData()
	windows.rots = PackedVector3Array()
	var stairs := newEmptyData()
	stairs.contact_pos = PackedVector3Array()
	stairs.rots = PackedVector3Array()
	stairs.ups = PackedByteArray()
	
	var wd = load_data( ctx, filename )
	if wd:
		for floor in wd.floors:
			curr_level = int(floor.level)
			importStream( ctx, floor, floors, "rooms", importRooms )
			importStream( ctx, floor, doors, "doors", importDoors )
			importStream( ctx, floor, windows, "windows", importWindows )
			importStream( ctx, floor, stairs, "stairs", importStairs )
		
		# Import the main entrance
		# I need a fake bulk in stream 0
		# Convert the root dict into an fake array or 1 item, parse it as a Window
		curr_level = 0
		wd.exit = [ wd.exit ]
		importStream( ctx, wd, doors, "exit", importWindows )

	outputStream( ctx, 0, floors )
	outputStream( ctx, 1, doors )
	outputStream( ctx, 2, windows )
	outputStream( ctx, 3, stairs )
