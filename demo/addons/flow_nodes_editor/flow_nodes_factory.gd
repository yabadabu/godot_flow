extends Node
class_name FlowNodesFactory

var node_types = { }
var new_name_counter : int = 0

const directory_path := "res://addons/flow_nodes_editor/nodes"

func getNewName( suffix : String ):
	new_name_counter += 1
	return "id_%04d_%s" % [ new_name_counter, suffix ]
	
func registerNodeType( node_type_name, file ):
	var full_res_path = directory_path + "/" + file
	var loaded_class : Script = load( full_res_path ) as Script
	if not loaded_class:
		push_error("Failed to load class %s" % full_res_path )
		return
	if not loaded_class.can_instantiate():
		push_error("Script cannot be instantiated: %s" % full_res_path)
		return
	print( "Loading class %s" % full_res_path )
	
	var instance = loaded_class.new() as FlowNodeBase
	var meta = instance.getMeta()
	meta.factory = loaded_class
	print( "Registering node type %s" % node_type_name )
	node_types[ node_type_name ] = meta

func scanAvailableNodes():
	var files := ResourceLoader.list_directory(directory_path) 
	for file in files:
		var stem = file.get_basename()
		if stem.ends_with("_settings"):
			continue
		registerNodeType( stem, file )
	print( "Registered %d node types" % node_types.size() )

func createNewNode( node_template : String, node_name : String, in_settings = null ):
	print( "createNewNode.node_template:", node_template )
	var meta = node_types.get( node_template, null )
	if not meta:
		if node_template.begins_with("input_"):
			registerNodeType( node_template, "input.gd")
			meta = node_types.get( node_template, null )
		else:
			push_error("node_type %s is not registered" % node_template)
			print( node_types.keys() )
			return null
			
	var flow_node := meta.factory.new() as FlowNodeBase
	if not flow_node is FlowNodeBase:
		push_error("Loaded script produced %s, expected FlowNodeBase: %s" % [flow_node.get_class(), meta.factory] )
		return
	print( "createNewNode.Meta:", str(meta) )
	print( "createNewNode.node_template: ", node_template )
	print( "node_name:", node_name )
	print( "flow_node:", flow_node )
	flow_node.name = node_name
	flow_node.template_name = node_template
	if in_settings: 
		FlowNodeIO.dict_to_resource( in_settings, flow_node )
	if not flow_node.title:
		flow_node.title = meta.get( "title", node_template )
	#flow_node.size = Vector2(32,32)
	#flow_node.refreshFromSettings()
	return flow_node
