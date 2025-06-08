@tool
extends FlowNodeBase

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
		
func spawnNode( root : Node, class_to_spawn ):
	var new_node = class_to_spawn.new()
	new_node.set_meta("flow_gen", true )	
	return new_node

func execute( ):
	var in_data = get_input(0)
	if !in_data:
		print( "Spawn.Input is invalid")
		return

	#in_data.dump( "Spawn" )

	var container = in_data.getContainerChecked( "position", FlowData.DataType.Vector )
	if container == null:
		push_error("Spawn.Missing stream position")
		return
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_error("Spawn.No scene opened")
		return

	removeOld( root )
	
	#print( "Spawning meshes children of %s" % [root.name])
		
	var mmi : MultiMeshInstance3D = spawnNode( root, MultiMeshInstance3D )
	if mmi == null:
		push_error( "Failed to spawn multiMeshInstance3D")
		return
	var multimesh := MultiMesh.new()
	multimesh.mesh = settings.mesh
	multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
	multimesh.instance_count = container.size()
	for idx in range( container.size() ):
		var transform : Transform3D = Transform3D( Basis.IDENTITY, container[idx] )
		multimesh.set_instance_transform( idx, transform )
	mmi.multimesh = multimesh
	root.add_child( mmi )
	mmi.owner = root 
	
	EditorInterface.mark_scene_as_unsaved()
