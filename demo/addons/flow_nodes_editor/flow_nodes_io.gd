extends Node
class_name FlowNodeIO

# Here are all functions related to read/write the resources, including 
# serialization to/from json for the clipboard

static func resource_to_dict(resource: Resource) -> Dictionary:
	var dict := {}
	for prop in resource.get_property_list():
		if prop.name in FlowNodeAssets.discardted_props:
			continue
		if prop.usage & PROPERTY_USAGE_STORAGE != 0:
			var name = prop.name
			dict[name] = resource.get(name)
	return dict
	
static func split_floats(in_str : String) -> Array:
	var parts = in_str.lstrip("(").rstrip(")").split(",")
	var vfloats = []
	for part in parts:
		vfloats.append( part.to_float() )
	return vfloats

static func _parse_resource_from_string(s: String) -> String:
	var start := s.find("res://")
	if start == -1:
		return ""

	var end := s.find("):", start)
	if end == -1:
		return ""

	return s.substr(start, end - start)

static func _parse_color(value) -> Color:
	if typeof(value) == TYPE_STRING:
		var parts = split_floats(value)
		return Color(parts[0], parts[1], parts[2], parts[3])
	return value

static func _parse_vector2(value) -> Vector2:
	if typeof(value) == TYPE_STRING:
		var parts = split_floats(value)
		return Vector2(parts[0], parts[1])
	if value == null:
		return Vector2(0,0)
	#print( "returning...", value)
	return value

static  func _parse_vector3(value) -> Vector3:
	if typeof(value) == TYPE_STRING:
		var parts = split_floats(value)
		return Vector3(parts[0], parts[1], parts[2])
	return value

static func dict_to_resource(data: Dictionary, resource: Resource) -> void:
	for prop in resource.get_property_list():
		var name = prop.name
		if name in FlowNodeAssets.discardted_props:
			continue
		if not data.has(name):
			continue
		var value = data[name]
		var type = prop.type
		match type:
			TYPE_COLOR:
				resource.set(name, _parse_color(value))
			TYPE_VECTOR2:
				resource.set(name, _parse_vector2(value))
			TYPE_VECTOR3:
				resource.set(name, _parse_vector3(value))
			_:
				if type == TYPE_ARRAY and typeof(value) == TYPE_ARRAY:
					var target_arr = resource.get(name)
					if target_arr != null and target_arr.is_typed():
						var target_arrary : Array = target_arr
						target_arr.clear()
						if target_arr.get_typed_builtin() == TYPE_VECTOR3:
							for item in value:
								target_arr.append(_parse_vector3(item))
						elif target_arr.get_typed_builtin() == TYPE_VECTOR2:
							for item in value:
								target_arr.append(_parse_vector2(item))
						elif target_arr.get_typed_builtin() == TYPE_COLOR:
							for item in value:
								target_arr.append(_parse_color(item))
						elif target_arr.get_typed_builtin() == TYPE_OBJECT:
							for item in value:
								if item and typeof(item) == TYPE_STRING:
									var res_name = _parse_resource_from_string( item )
									if res_name:
										var obj = load( res_name )
										if obj:
											target_arr.append(obj)
								else:
									target_arr.append(item)
									
						else:
							# print( "Array is of type %s" % [ target_arr.get_typed_builtin() ])
							for item in value:
								target_arr.append(item)
					else:
						resource.set(name, value)
				else:
					resource.set(name, value)

static func nodes_as_dict( nodes, frames, editor : FlowGraphEditor ):
	var exported_node_names = {}
	
	# Find the top-left coord of all nodes beign exported
	var min_pos = null
	for node in nodes:
		var pos = node.position_offset / editor.ui_scale
		if min_pos == null:
			min_pos = pos
		else:
			min_pos.x = minf( min_pos.x, pos.x )
			min_pos.y = minf( min_pos.y, pos.y )
	
	var nodes_clean = nodes.map( func( node ):
		exported_node_names[ node.name ] = 1
		node.refreshConnectionFlags()
		
		return {
			"position" : ( node.position_offset - min_pos ) / editor.ui_scale,
			"name" : node.name,
			"template" : node.node_template,
			"show_disconnected_inputs" : node.show_disconnected_inputs,
			"args_port" : node.args_ports_by_name,
			"settings" : resource_to_dict( node.settings ),
		}
	)
	
	var links = []
	for connection in editor.gedit.connections:
		if connection.from_node in exported_node_names and connection.to_node in exported_node_names:
			links.append( connection )
			
	var frames_clean = frames.map( func( node ):
		var attached : Array[StringName] = editor.gedit.get_attached_nodes_of_frame(node.name)
		return {
			"position" : ( node.position_offset - min_pos ) / editor.ui_scale,
			"size" : node.size,
			"name" : node.name,
			"tint_color" : node.tint_color,
			"title" : node.title,
			"attached" : attached,
		}
	)		
			
	var data := {
		"type" : "flow_graph_nodes",
		"version" : 1,
		"min_pos" : min_pos,
		"nodes" : nodes_clean,
		"links" : links,
		"frames" : frames_clean,
	}
	return data

static func _paste_nodes_from_dict( dict, editor : FlowGraphEditor, at_graph_coords = null):
	if typeof(dict) != TYPE_DICTIONARY:
		return []
	# Read paste coords from mouse
	var mouse_pos = editor.get_local_mouse_position()
	var graph_coords : Vector2 = editor.localToGraphCoords( mouse_pos )
	if at_graph_coords:
		graph_coords = at_graph_coords
		
	var new_nodes = create_nodes_from_dict( dict, editor.current_resource, graph_coords )
	
	# Update selection
	for node in editor.getSelectedNodes():
		node.selected = false
		
	if new_nodes:
		for node in new_nodes:
			node.selected = true

# Expects container to provide the following methods:
#   addNodeFromTemplate
#   connect_nodes
#   addFrame
static func create_nodes_from_dict( dict, container, paste_offset = null):		
	if dict.get( "type", null) != "flow_graph_nodes":
		push_error( "Invalid dict to paste nodes from" )
		return []
	var new_nodes = []
	var old_to_new_names = {}
	
	var ui_scale = 1.0			# container.ui_scale
	
	for in_node in dict.nodes:
		if not in_node:
			return null
		var in_name = in_node.name
		print( "Parsing node %s" % in_name )
		
		var node = container.addNodeFromTemplate( in_node.template, in_name )
		if not node:
			return null
		var in_pos = _parse_vector2( in_node.position )
		node.position_offset = ( in_pos + paste_offset ) * ui_scale
		print( "New node pos %s will be %s" % [ in_name, node.position_offset ] )
		node.show_disconnected_inputs = in_node.get("show_disconnected_inputs", false)
		node.args_ports_by_name = in_node.get("args_port", {})
		
		# Apply saved settings...
		dict_to_resource( in_node.settings, node.settings )
		
		# Never inport the inspect_enabled
		node.settings.inspect_enabled = false
		
		node.initFromScript();
		
		node.refreshFromSettings()
		
		# Update relation old -> new for the links
		old_to_new_names[ in_name ] = node.name
		new_nodes.append( node )
		
	# Recreate the links
	for link in dict.links:
		var new_from = old_to_new_names.get( link.from_node, null )
		var new_to = old_to_new_names.get( link.to_node, null )
		if new_from == null or new_to == null:
			push_error( "Failed to identify params links", link)
			continue
		container.connect_nodes(new_from, link.from_port, new_to, link.to_port )

	for frame_data in dict.get( "frames", [] ):
		container.addFrame(frame_data, old_to_new_names, paste_offset)

	return new_nodes

static func copySelectionToClipboard( editor : FlowGraphEditor ):
	var nodes = editor.getSelectedNodes()
	var frames = editor.getSelectedFrames()
	var json_str = JSON.stringify( nodes_as_dict( nodes, frames, editor ), "\t")
	DisplayServer.clipboard_set( json_str )

static func pasteNodeFromClipboard( editor : FlowGraphEditor ):
	var json_str = DisplayServer.clipboard_get( )
	var dict := JSON.parse_string(json_str)
	_paste_nodes_from_dict( dict, editor )

static func duplicateSelecteddNodes( editor : FlowGraphEditor ):
	var nodes = editor.getSelectedNodes()
	var frames = editor.getSelectedFrames()
	var dict = nodes_as_dict(nodes, frames, editor )
	_paste_nodes_from_dict( dict, editor )

static func saveEditorStateToResource( editor : FlowGraphEditor ):
	var all_nodes := editor.getAllNodes()
	for node in all_nodes:
		print( "Node %s is at %s" % [ node.name, node.position_offset ])
	var all_frames = editor.gedit.get_children().filter( func( n ):
		return n is GraphFrame
	)
	var res = editor.current_resource
	print( "unbindResourceFromEditor %d nodes, %d conns and %d frames" % [ all_nodes.size(), editor.gedit.connections.size(), all_frames.size() ] )
	res.data = FlowNodeIO.nodes_as_dict( all_nodes, all_frames, editor )
	res.view_zoom = editor.gedit.zoom
	res.view_offset = editor.gedit.scroll_offset
	print( res.data )
