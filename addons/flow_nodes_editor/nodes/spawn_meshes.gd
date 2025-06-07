@tool
extends FlowNodeBase

@export var value : float = 2.0

func getMeta() -> Dictionary :
	return {
		"title" : "Spawn Meshes",
		"settings" : SpawnMeshesNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }, { "label" : "Removed" }],
	}

func isFinal() -> bool:
	return true
	
func removeOld( root : Node):
	var children_to_remove =[]
	for child in root.get_children():
		if child.has_meta("flow_gen"):
			children_to_remove.append( child )
	for child in children_to_remove:
		root.remove_child(child)
		child.free()	

func execute( ):
	var in_data = get_input(0)
	if !in_data:
		print( "Spawn.Input is invalid")
		return

	in_data.dump( "Spawn" )

	var container = in_data.getContainerChecked( "position", FlowData.DataType.Vector )
	if container == null:
		push_error("Spawn.Missing stream position")
		return
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_error("Spawn.No scene opened")
		return

	removeOld( root )
		
	print( "Spawning meshes children of %s" % [root.name])
		
	for p in container:
		var new_node = Node3D.new()
		root.add_child( new_node )
		new_node.owner = root 
		new_node.position = p
		new_node.set_meta("flow_gen", true )
	
	EditorInterface.mark_scene_as_unsaved()
		
	#for stream in input.streams.values():
		#print( "%s (%s) %d elems" % [ stream.name, stream.data_type, stream.container.size() ] )
		#for data in stream.container:
			#print( "  %s" % str(data ))
	#var output = []
	#set_output( 0, output )
