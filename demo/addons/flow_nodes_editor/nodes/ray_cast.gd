@tool
extends FlowNodeBase

@export var dir : Vector3 = Vector3.DOWN
@export var max_distance : float = 1e3

@export var from_attribute : String = "position"

@export var out_result_attribute : String = "hit"
@export var out_position_attribute : String = "position"
@export var out_rotation_attribute : String = "rotation"

func _init():
	meta_node = {
		"title" : "Ray Cast",
		"category" : "Spatial",
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
	var ipos = in_data.getContainerChecked( from_attribute, FlowData.DataType.Vector )
	if not ipos:
		setError( "Stream %s of type Vector not found in input data" % from_attribute )
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
	
	var scaled_dir : Vector3 = dir * max_distance
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
	
	if out_position_attribute:
		out_data.registerStream( out_position_attribute, opos )
	if out_rotation_attribute:
		for i in in_size:
			if ohit[i]:
				orot[i] = FlowData.basisToEuler( FlowData.basisFromNormal( orot[i] ) ) + Vector3( 90,0,0 )
		out_data.registerStream( out_rotation_attribute, orot )
	if out_result_attribute:
		out_data.registerStream( out_result_attribute, ohit )
	set_output( 0, out_data )
