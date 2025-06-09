@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Ray Cast",
		"settings" : RayCastNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( _ctx : FlowData.EvaluationContext ):
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return null
	
	var world = root.get_world_3d()
	if not world:
		return null
	var space_state = world.direct_space_state
	
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	var spos : PackedVector3Array = out_data.cloneStream( "position" )
	var scaled_dir : Vector3 = settings.dir * settings.max_distance
	var ray_start := Vector3(0,0,0)
	var ray_end := ray_start + scaled_dir
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	var nmisses = 0
	for i in spos.size():
		query.from = spos[i]
		query.to = query.from  + scaled_dir
		var result = space_state.intersect_ray(query)
		if result:
			var hit_position = result.position
			spos[i] = hit_position
		else:
			nmisses += 1
	if nmisses > 0:
		print( "%d Rays failed" % [nmisses])
	set_output( 0, out_data )
