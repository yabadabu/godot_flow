extends Node
class_name FlowNodesFactory

var node_types = { }

const directory_path := "res://addons/flow_nodes_editor/nodes"

func registerNodeType( node_type_name, file ):
	var full_res_path = directory_path + "/" + file
	var loaded_class : Script = load( full_res_path ) as Script
	if not loaded_class:
		push_error("Failed to load class %s" % full_res_path )
		return
	#print( "Loading class %s" % full_res_path )
	var instance = loaded_class.new() as FlowNodeBase
	var meta = instance.getMeta()
	meta.factory = loaded_class
	#print( "Registering node type %s" % node_type_name )
	node_types[ node_type_name ] = meta

func scanAvailableNodes():
	var files := ResourceLoader.list_directory(directory_path) 
	for file in files:
		var stem = file.get_basename()
		if stem.ends_with("_settings"):
			continue
		registerNodeType( stem, file )
	print( "Registered %d node types" % node_types.size() )


func createNewNode( packed_node, node_template : String, node_name : String, settings = null ):
	var meta = node_types.get( node_template, null )
	if not meta:
		push_error("node_type %s is not registered" % node_template)
		print( node_types.keys() )
		return null	
	var node : GraphNode
	if packed_node:
		node = packed_node.instantiate() as GraphNode
		node.set_script(meta.factory)
	else:
		node = meta.factory.new() as FlowNodeBase
	#print( "Meta:", str(meta) )

	node.node_template = node_template
	node.name = node_name
	if settings:
		node.settings = settings
	else:
		if meta.has( "settings" ):
			#print( "Assigning settings of type %s" % meta.settings )
			#print( "node is %s" % node )
			node.settings = meta.settings.new()
		else:
			#print( "Assigning default settings" )
			node.settings = NodeSettings.new()
	node.settings.title = meta.title
	node.initFromScript()
	node.title = node.getTitle()
	node.size = Vector2(32,32)
	node.tooltip_text = meta.get( "tooltip", "" )
	node.refreshFromSettings()
	return node
