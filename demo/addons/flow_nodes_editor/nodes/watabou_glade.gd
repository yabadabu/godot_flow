@tool
extends FlowNodeBase

@export_file var filename : String

func _init():
	meta_node = {
		"title" : "Watabou Glade",
		"category" : "Import",
		"ins" : [],
		"outs" : [
			{ "label" : "Contours" }, 
		],
		"tooltip" : "Imports a watabou Glade exported in .svg format",
	}

func parsePaths( str : String ):
	var paths = []
	# Split on "M" to separate subpaths, preserving structure without
	# per-point string splitting
	var subpaths = str.strip_edges().split("M", false)
	for sp in subpaths:
		var clean = sp.replace("L", " ").replace(",", " ")
		var floats = clean.split_floats(" ", false)
		var count = floats.size() / 2
		if count == 0:
			continue
		var path = PackedVector3Array()
		path.resize(count)
		for i in count:
			path[i] = Vector3(floats[i * 2], 0, floats[i * 2 + 1])
		paths.append(path)
	return paths

func load_data( ctx : FlowData.EvaluationContext, infilename : String ) -> Dictionary:
	var data: Dictionary = { "paths": [] }
	if infilename.strip_edges().is_empty():
		setError( ctx, "Missing filename")
		return data
	var file := FileAccess.open(infilename, FileAccess.READ)
	if file == null:
		setError( ctx, "Could not open: " + infilename)
		return data
	var parser = XMLParser.new()
	parser.open(infilename)
	var depth : int = 0
	var clip_path_founds : = 0
	var num_paths : int = 0
	while parser.read() != ERR_FILE_EOF:
		var node_type = parser.get_node_type()
		var node_name = "text" if node_type == XMLParser.NODE_TEXT else parser.get_node_name() 
		#print( "D:%d node:%s" % [ depth, node_name ] )
		if node_name == "g":
			if node_type == XMLParser.NODE_ELEMENT:
				depth += 1
			elif node_type == XMLParser.NODE_ELEMENT_END:
				depth -= 1
		elif node_name == "clipPath":
			clip_path_founds += 1
		elif node_type == XMLParser.NODE_ELEMENT:
			if node_name != "path":
				continue
			if depth != 3:
				continue
			if clip_path_founds != 2:
				continue
			num_paths += 1
			if num_paths != 2:
				continue
			
			for idx in range(parser.get_attribute_count()):
				if parser.get_attribute_name(idx) == "d":
					data.paths = parsePaths( parser.get_attribute_value(idx) )
					return data
	
	return data

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
	#var time_start = Time.get_ticks_usec()
	var wd = load_data( ctx, filename )
	#print( "%.3f ms" % [ (Time.get_ticks_usec() - time_start) / 1000.0 ] )
	if wd:
		for path in wd.paths:
			#print( "Path: %d" % path.size() )
			var d = FlowData.Data.new()
			d.addCommonStreams( path.size() )
			d.registerStream( FlowData.AttrPosition, path )
			setOutput( ctx, 0, d )
