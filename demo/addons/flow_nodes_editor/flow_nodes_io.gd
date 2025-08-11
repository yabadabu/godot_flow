extends Node
class_name FlowNodeIO

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

static func _parse_color(value) -> Color:
	if typeof(value) == TYPE_STRING:
		var parts = split_floats(value)
		return Color(parts[0], parts[1], parts[2], parts[3])
	return value

static func _parse_vector2(value) -> Vector2:
	if typeof(value) == TYPE_STRING:
		var parts = split_floats(value)
		return Vector2(parts[0], parts[1])
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
				resource.set(name, value)

static func nodes_as_dict( nodes, editor : FlowGraphEditor ):
	var exported_node_names = {}
	
	# Find the top-left coord of all nodes
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
	var data := {
		"type" : "flow_graph_nodes",
		"version" : 1,
		"min_pos" : min_pos,
		"nodes" : nodes_clean,
		"links" : links
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
		
	var new_nodes = create_nodes_from_dict( dict, editor, graph_coords )
	
	# Update selection
	for node in editor.getSelectedNodes():
		node.selected = false
	for node in new_nodes:
		node.selected = true

static func create_nodes_from_dict( dict, editor : FlowGraphEditor, paste_offset = null):		
	if dict.get( "type", null) != "flow_graph_nodes":
		push_error( "Invalid dict to paste nodes from" )
		return []
	var new_nodes = []
	var old_to_new_names = {}
	for in_node in dict.nodes:
		var in_name = in_node.name
		var new_name = in_name
		if editor.gedit_nodes_by_name.has( in_name ):
			new_name = editor.getNewName(in_node.template)
		var node = editor.addNodeFromTemplate( in_node.template, new_name )
		if not node:
			return null
		var in_pos = _parse_vector2( in_node.position )
		node.position_offset = ( in_pos + paste_offset ) * editor.ui_scale
		node.show_disconnected_inputs = in_node.show_disconnected_inputs
		node.args_ports_by_name = in_node.args_port
		
		# Apply saved settings...
		dict_to_resource( in_node.settings, node.settings )
		
		node.initFromScript();
		
		node.refreshFromSettings()
		
		# Update relation old -> new for the links
		old_to_new_names[ in_name ] = new_name
		new_nodes.append( node )
		
	# Recreate the links
	for link in dict.links:
		var new_from = old_to_new_names.get( link.from_node, null )
		var new_to = old_to_new_names.get( link.to_node, null )
		if new_from == null or new_to == null:
			push_error( "Failed to identify params links", link)
			continue
		editor.connect_nodes(new_from, link.from_port, new_to, link.to_port )

	return new_nodes

static func copySelectionToClipboard( editor : FlowGraphEditor ):
	var nodes = editor.getSelectedNodes()
	var json_str = JSON.stringify( nodes_as_dict( nodes, editor ), "\t")
	DisplayServer.clipboard_set( json_str )

static func pasteNodeFromClipboard( editor : FlowGraphEditor ):
	var json_str = DisplayServer.clipboard_get( )
	var dict := JSON.parse_string(json_str)
	_paste_nodes_from_dict( dict, editor )

static func duplicateSelecteddNodes( editor : FlowGraphEditor ):
	var nodes = editor.getSelectedNodes()
	var dict = nodes_as_dict(nodes, editor )
	_paste_nodes_from_dict( dict, editor )

static func saveToResource( editor : FlowGraphEditor ):
	var current_resource = editor.current_resource
	if current_resource == null:
		return
	var gedit = editor.gedit
	var all_nodes = gedit.get_children().filter( func( n ):
		return n is FlowNodeBase
	)
	current_resource.data = nodes_as_dict( all_nodes, editor )
	current_resource.view_zoom = gedit.zoom
	current_resource.view_offset = gedit.scroll_offset
	current_resource.new_name_counter = editor.new_name_counter

static func loadFromResource( editor : FlowGraphEditor ):
	var current_resource = editor.current_resource
	if current_resource == null:
		return

	var node_in_data_inspector = null
	
	# Register the input_* nodes before trying to load the nodes
	for input in current_resource.in_params:
		editor.registerInputNodeType( input )
		
	if current_resource.data and not current_resource.data.is_empty():
		var paste_offset = _parse_vector2( current_resource.data.min_pos )
		create_nodes_from_dict( current_resource.data, editor, paste_offset )
		
	editor.gedit.zoom = current_resource.view_zoom
	editor.gedit.scroll_offset = current_resource.view_offset
	editor.new_name_counter = current_resource.new_name_counter
	editor.data_inspector.setNode( node_in_data_inspector )
