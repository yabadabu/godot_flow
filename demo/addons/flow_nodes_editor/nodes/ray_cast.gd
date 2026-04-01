@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Ray Cast",
		"settings" : RayCastNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Traces a ray in the current scene from the point position (the attribute can be redefined).\n" + 
					"The output position, rotation and hit result can be stored\n" + 
					"Use a Filter by hit  with True or 1 to remove the points where the trace failed.\n"
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
	var in_size = in_data.size()
	var out_data : FlowData.Data = in_data.duplicate()
	var ipos = in_data.getContainerChecked( settings.from_attribute, FlowData.DataType.Vector )
	if not ipos:
		setError( "Stream %s of type Vector not found in input data" % settings.from_attribute )
		return null
	var source_container : PackedVector3Array = ipos
		
	var opos : PackedVector3Array
	var orot : PackedVector3Array
	var ohit : PackedByteArray
	# Assign initial values for the rotation.
	if in_data.hasStreamOfType( FlowData.AttrRotation, FlowData.DataType.Vector ):
		var irot = in_data.getContainerChecked( FlowData.AttrRotation, FlowData.DataType.Vector )
		orot.append_array( irot )
	else:
		orot.resize( in_size )
	opos.append_array( ipos )
	ohit.resize( in_size )
	
	var scaled_dir : Vector3 = settings.dir * settings.max_distance
	var ray_start := Vector3(0,0,0)
	var ray_end := ray_start + scaled_dir
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	var nmisses = 0
	for i in range(in_size):
		query.from = source_container[i]
		query.to = query.from  + scaled_dir
		var result : Dictionary = space_state.intersect_ray(query)
		if result:
			opos[i] = result.position
			orot[i] = result.normal
			ohit[i] = 1
		else:
			ohit[i] = 0
	
	if settings.out_position_attribute:
		out_data.registerStream( settings.out_position_attribute, opos )
	if settings.out_rotation_attribute:
		for i in in_size:
			if ohit[i]:
				orot[i] = FlowData.basisToEuler( FlowData.basisFromNormal( orot[i] ) ) + Vector3( 90,0,0 )
		out_data.registerStream( settings.out_rotation_attribute, orot )
	if settings.out_result_attribute:
		out_data.registerStream( settings.out_result_attribute, ohit )
	set_output( 0, out_data )
