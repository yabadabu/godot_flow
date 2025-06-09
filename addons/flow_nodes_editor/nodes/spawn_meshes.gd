@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Spawn Meshes",
		"settings" : SpawnMeshesNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }, { "label" : "Removed" }],
	}

func _exit_tree():
	#removeInstancedComponents();
	pass

func isFinal() -> bool:
	return true
	
func removeInstancedComponents( root : Node3D ):
	var comps = []
	for child in root.get_children():
		var mmi = child as MultiMeshInstance3D
		if mmi and mmi.get_meta( "flow_owner" ) == name:
			comps.append( mmi )
	for comp in comps:
		comp.queue_free()
		
func spawnNode( root : Node, class_to_spawn ):
	var new_node = class_to_spawn.new()
	new_node.set_meta("flow_owner", name )	
	return new_node

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if !in_data:
		setError( "Spawn.Input is invalid")
		return

	#in_data.dump( "Spawn" )

	var container : PackedVector3Array = in_data.getContainerChecked( FlowData.AttrPosition, FlowData.DataType.Vector )
	if container == null:
		setError("Spawn.Missing stream position")
		return
		
	var root = ctx.owner
	if not root:
		setError("Spawn.No node3d assigned in context")
		return

	removeInstancedComponents( root )
	
	#print( "Spawning meshes children of %s" % [root.name])
		
	var mmi : MultiMeshInstance3D = spawnNode( root, MultiMeshInstance3D )
	if mmi == null:
		setError( "Failed to spawn multiMeshInstance3D")
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
	
	var scene_root = root.get_tree().current_scene
	if scene_root:
		mmi.owner = scene_root
	else:
		# Fallback: find the top-most node with an owner
		var current = root
		while current.get_parent() and current.owner:
			current = current.get_parent()
		mmi.owner = current	
	
	print( "mmi added to %s (Owner:%s)" % [ root.name, mmi.owner.name ])
	EditorInterface.mark_scene_as_unsaved()

	set_output(0, in_data)
