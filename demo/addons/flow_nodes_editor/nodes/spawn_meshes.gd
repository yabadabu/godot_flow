@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Spawn Meshes",
		"settings" : SpawnMeshesNodeSettings,
		"category" : "Spawner",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"is_final" : true,
		"tooltip" : "Spawns a Mesh Instance on each point, applying the translation, rotation and scale.\nThe instanced mesh can be specified by point if a stream contains the mesh resource to be spawned.\nThe generates meshes are MultiMeshInstance3D.",
	}
	
var spawn_id : int = 0

func _exit_tree():
	#removeInstancedComponents();
	pass
	
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

func _resolve_spawn_parent(root : Node3D) -> Node3D:
	var path = settings.spawn_parent_path.strip_edges()
	if path == "":
		return root
	var n = root.get_node_or_null(path)
	if n is Node3D:
		return n
	setError("Spawn parent path '%s' is invalid or not a Node3D" % path)
	return root

func _build_variant_weights( num_variants : int ) -> Array[float]:
	if num_variants == 0:
		return []
	var weights : Array[float] = []
	weights.resize(num_variants)
	for i in range(num_variants):
		var w = 1.0
		if i < settings.mesh_variant_weights.size():
			w = maxf(0.0, float(settings.mesh_variant_weights[i]))
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

func _resolve_mesh_for_point(idx : int, meshes_stream, variants : Array[Mesh], variant_weights : Array[float], selector_stream) -> Mesh:
	if meshes_stream != null:
		var read_idx = idx if meshes_stream.size() > 1 else 0
		var m = meshes_stream[read_idx] as Mesh
		if m != null:
			return m

	if settings.randomize_mesh_variants:
		var ridx = _pick_weighted_variant(variant_weights, rng.randf())
		return variants[ridx]

	if selector_stream != null:
		var read_idx = idx if selector_stream.container.size() > 1 else 0
		var selector_value = float(selector_stream.container[read_idx])
		var sval = clampf(selector_value, 0.0, 1.0)
		var ridx = _pick_weighted_variant(variant_weights, sval)
		return variants[ridx]

	var cycle_idx = idx % variants.size()
	return variants[cycle_idx]
	
func preExecute( ctx : FlowData.EvaluationContext ):
	super.preExecute(ctx)
	var spawn_parent = _resolve_spawn_parent(ctx.owner)
	if settings.clear_previous_instances:
		removeRegisteredInstancedNodes( spawn_parent )
	spawn_id = 0
		
func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	if !in_data || in_data.size() == 0:
		set_output(0, in_data)
		return

	var meshes = null
	if settings.mesh_attribute:
		var stream_meshes = in_data.findStream( settings.mesh_attribute )
		if stream_meshes == null:
			setError( "Input does not have attribute '%s'" % settings.mesh_attribute)
			return
		if stream_meshes.data_type != FlowData.DataType.Resource:
			setError( "Attribute '%s' should be of type Resource" % settings.mesh_attribute)
			return
		meshes = stream_meshes.container
		
	var selector_stream = null
	if settings.mesh_selector_attribute.strip_edges() != "":
		selector_stream = in_data.findStream(settings.mesh_selector_attribute)
		if selector_stream != null and selector_stream.data_type != FlowData.DataType.Int and selector_stream.data_type != FlowData.DataType.Float:
			setError("Mesh selector attribute '%s' must be Int or Float" % settings.mesh_selector_attribute)
			return
		if selector_stream != null:
			var sel_size = selector_stream.container.size()
			if sel_size != in_data.size() and sel_size != 1:
				setError("Mesh selector attribute '%s' must have %d values or 1 value (got %d)" % [settings.mesh_selector_attribute, in_data.size(), sel_size])
				return

	# Discard non-valid meshes
	var variants : Array[Mesh] = []
	for v in settings.mesh_variants:
		if v != null:
			variants.append(v)
	var variant_weights = _build_variant_weights( variants.size() )

	var transforms := in_data.getTransformsStream()
	if transforms == null:
		setError("Missing transforms information")
		return

	var root = ctx.owner
	if not root:
		set_output(0, in_data)
		setError("Failed to find root")
		return
		
	var spawn_parent = _resolve_spawn_parent(root)
	var in_size = in_data.size()

	# Find who is going to be the owner of the new nodes
	# (shoulw be the parent root of the scene, not the parent)
	var node_tree = root.get_tree()
	if not node_tree:
		setError("Invalid current scene")
		return
		
	var scene_root = node_tree.current_scene
	if not root.get_tree():
		setError("Invalid scene_root scene")
		return
		
	var owner_of_mmis : Node
	if scene_root:
		owner_of_mmis = scene_root
	else:
		# Fallback: find the top-most node with an owner
		owner_of_mmis = root
		while owner_of_mmis.get_parent() and owner_of_mmis.owner:
			owner_of_mmis = owner_of_mmis.get_parent()

	if variants.is_empty() and meshes == null:
		setError("Provide mesh_attribute, or mesh_variants.")
		return

	# Collect which indices use the same resource.
	var mmis := {}
	for idx in range( in_size ):
		var mesh = _resolve_mesh_for_point(idx, meshes, variants, variant_weights, selector_stream)
		#print( "Meshes[%d] is %s" % [ idx, mesh ])
		if mesh == null:
			continue
		var key = mesh
		var mmi = mmis.get( key, null )
		if mmi == null:
			mmis[ key ] = []
		mmis[ key ].append( idx )
	
	var color_stream = in_data.findStream(settings.color_attribute)
	var has_colors = settings.use_vertex_colors and color_stream != null and color_stream.data_type == FlowData.DataType.Color
	if has_colors:
		var color_size = color_stream.container.size()
		if color_size != in_size and color_size != 1:
			setError("Color attribute '%s' must have %d values or 1 value (got %d)" % [settings.color_attribute, in_size, color_size])
			return

	var prefix = title

	for res in mmis.keys():
		var mmi : MultiMeshInstance3D = spawnNode( root, MultiMeshInstance3D )
		mmi.name = "%s_%04d" % [ prefix, spawn_id ]
		spawn_id += 1
		
		var multimesh := MultiMesh.new()
		multimesh.mesh = res
		multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
		if has_colors:
			multimesh.use_colors = true
		var ids = mmis[res]
		multimesh.instance_count = ids.size()
		
		# We could also create a large buffer and perform a single update
		var idx := 0
		for id in ids:
			multimesh.set_instance_transform( idx, transforms.atIndex( id ) )
			if has_colors:
				multimesh.set_instance_color( idx, color_stream.container[id] )
			idx += 1
			
		mmi.multimesh = multimesh
		if has_colors:
			# This is kind of arbitrary
			var mat = StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.3
			mmi.material_override = mat
		
		registerInstancedNode(owner_of_mmis, spawn_parent, mmi)
	
	EditorInterface.mark_scene_as_unsaved()

	set_output(0, in_data)
