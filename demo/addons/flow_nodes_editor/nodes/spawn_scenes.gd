@tool
extends FlowNodeBase

var spawn_id : int = 0

func _init():
	meta_node = {
		"title" : "Spawn Scenes",
		"settings" : SpawnScenesNodeSettings,
		"category" : "Spawner",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"is_final" : true,
		"tooltip" : "Similar to spawn meshes but a full scene is instantiated on each node.\nA set of properties can be transfered from the nodes to each instanced scene.",
	}

func _exit_tree():
	#removeInstancedComponents();
	pass


func _resolve_spawn_parent(root : Node3D) -> Node3D:
	var path = settings.spawn_parent_path.strip_edges()
	if path == "":
		return root
	var n = root.get_node_or_null(path)
	if n is Node3D:
		return n
	setError("Spawn parent path '%s' is invalid or not a Node3D" % path)
	return root

func _build_variant_weights() -> Array[float]:
	var variants = settings.scene_variants
	if variants.is_empty():
		return []
	var weights : Array[float] = []
	weights.resize(variants.size())
	for i in range(variants.size()):
		var w = 1.0
		if i < settings.scene_variant_weights.size():
			w = maxf(0.0, float(settings.scene_variant_weights[i]))
		weights[i] = w
	var total = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		for i in range(weights.size()):
			weights[i] = 1.0
	return weights

func _pick_weighted_variant(weights : Array[float], rnd : float) -> int:
	var total = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var t = rnd * total
	var accum = 0.0
	for i in range(weights.size()):
		accum += weights[i]
		if t <= accum:
			return i
	return weights.size() - 1

func _resolve_scene_for_point(idx : int, scenes_stream, variants : Array[PackedScene], variant_weights : Array[float], selector_stream):
	if scenes_stream != null:
		var read_idx = idx if scenes_stream.size() > 1 else 0
		var scene_val = scenes_stream[read_idx] as PackedScene
		if scene_val != null:
			return scene_val
			
		# Falling back to use the variants...
	
	if variants.is_empty():
		return null
	
	if settings.randomize_scene_variants:
		var ridx = _pick_weighted_variant(variant_weights, rng.randf())
		return variants[ridx]
		
	if selector_stream != null:
		var read_idx = idx if selector_stream.container.size() > 1 else 0
		if selector_stream.data_type == FlowData.DataType.Int:
			var int_idx = clampi(int(selector_stream.container[read_idx]), 0, variants.size() - 1)
			return variants[int_idx]
		var selector_value = float(selector_stream.container[read_idx])
		var sval = clampf(selector_value, 0.0, 1.0)
		var ridx = _pick_weighted_variant(variant_weights, sval)
		return variants[ridx]
	return variants[idx % variants.size()]
		
func _find_owner_of_spawned_nodes( root : Node) -> Node:

	# Find who is going to be the owner of the new nodes
	# (should be the parent root of the scene, not the parent)
	var node_tree = root.get_tree()
	if not node_tree:
		setError("Invalid current scene")
		return null
		
	var scene_root = node_tree.current_scene
	if not root.get_tree():
		setError("Invalid scene_root scene")
		return null
		
	var new_owner : Node
	if scene_root:
		new_owner = scene_root
	else:
		# Fallback: find the top-most node with an owner
		new_owner = root
		while new_owner.get_parent() and new_owner.owner:
			new_owner = new_owner.get_parent()	
	return new_owner
		
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute( ctx )
	var spawn_parent = _resolve_spawn_parent(ctx.owner)
	if settings.clear_previous_instances:
		removeRegisteredInstancedNodes( spawn_parent )
	spawn_id = 0
		
func execute( ctx : FlowData.EvaluationContext ):

	var in_data : FlowData.Data = get_input(0)
	if !in_data:
		set_output(0, FlowData.Data.new())
		return

	var in_size = in_data.size()
	if in_size == 0:
		set_output(0, in_data)
		return

	# The scenes is going to be defined in an attribute?
	var scenes = null
	if settings.scene_attribute:
		var stream_scenes = in_data.findStream( settings.scene_attribute )
		if stream_scenes == null:
			setError( "Input does not have attribute '%s'" % settings.scene_attribute)
			return
		if stream_scenes.data_type != FlowData.DataType.Resource:
			setError( "Attribute '%s' should be of type Resource Packed Scene" % settings.scene_attribute)
			return
		scenes = stream_scenes.container

	var selector_stream = null
	if settings.scene_selector_attribute.strip_edges() != "":
		selector_stream = in_data.findStream(settings.scene_selector_attribute)
		if selector_stream != null and selector_stream.data_type != FlowData.DataType.Int and selector_stream.data_type != FlowData.DataType.Float:
			setError("Scene selector attribute '%s' must be Int or Float" % settings.scene_selector_attribute)
			return
		if selector_stream != null:
			var sel_size = selector_stream.container.size()
			if sel_size != in_data.size() and sel_size != 1:
				setError("Scene selector attribute '%s' must have %d values or 1 value (got %d)" % [settings.scene_selector_attribute, in_data.size(), sel_size])
				return

	var root = ctx.owner
	if not root:
		setError("Failed to find root")
		set_output(0, in_data)
		return

	var transforms = in_data.getTransformsStream()
	if transforms == null:
		setError("Missing required streams %s/%s" % [ FlowData.AttrPosition, FlowData.AttrRotation ])
		set_output(0, in_data)
		return

	var owner_of_spawned_nodes := _find_owner_of_spawned_nodes( ctx.owner )
		
	var spawn_parent = _resolve_spawn_parent(root)

	var variants : Array[PackedScene] = []
	for v in settings.scene_variants:
		if v != null:
			variants.append(v)
	var variant_weights = _build_variant_weights()
	if variants.is_empty() and scenes == null:
		setError("No scene source configured. Provide scene, scene_attribute, or scene_variants.")
		return

	# Save which data is needed for customization
	var streams_to_assign = []
	for node_property in settings.assign_attributes:
		var stream_name = settings.assign_attributes[ node_property ]
		var stream = in_data.findStream( stream_name )
		if stream:
			streams_to_assign.append( { "node_property" : node_property, "container" : stream.container } )

	# Each point will spawn a full scene, no option for instancing
	for idx in range( in_size ):
		var packed_scene : PackedScene = _resolve_scene_for_point(idx, scenes, variants, variant_weights, selector_stream)
		if not packed_scene:
			continue
		var created = packed_scene.instantiate()
		var node : Node3D = created as Node3D
		if node == null:
			if created:
				created.queue_free()
			setError("Instanced scene is not a Node3D at index %d" % idx)
			return
		node.transform = transforms.atIndex( idx )
		node.name = "%s_%04d" % [ name, spawn_id + idx ]
		
		registerInstancedNode(owner_of_spawned_nodes, spawn_parent, node)
		
		# Identify which node will need customization
		var assign_target : Node = node
		var assign_target_path = settings.assign_target_path.strip_edges()
		if assign_target_path != "":
			var target_node = node.get_node_or_null(assign_target_path)
			if target_node:
				assign_target = target_node
				
		# Customize the generated scene
		for s in streams_to_assign:
			var read_idx = idx if s.container.size() > 1 else 0
			assign_target.set( s.node_property, s.container[ read_idx ])
	
	spawn_id += in_size
	EditorInterface.mark_scene_as_unsaved()
	set_output(0, in_data)
