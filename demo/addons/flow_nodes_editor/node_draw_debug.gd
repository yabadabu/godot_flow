extends Node
class_name NodeDrawDebug

var node : FlowNodeBase

# Render
var scenario_rid : RID
var multimesh_rid : RID
var instance_rid : RID
var mesh_resource: Mesh = preload( "res://addons/flow_nodes_editor/resources/unit_cube.tres" )
var selection_color := Color.MAGENTA
	
func _ready():
	var viewport = get_viewport()
	if viewport and viewport.get_world_3d():
		scenario_rid = viewport.get_world_3d().scenario
	
func _exit_tree():
	cleanup_multimesh_direct()
	
func cleanup_multimesh_direct():
	if instance_rid.is_valid():
		RenderingServer.free_rid(instance_rid)
		instance_rid = RID()

	if multimesh_rid.is_valid():
		RenderingServer.free_rid(multimesh_rid)
		multimesh_rid = RID()	

func create_multimesh_direct():
	if not mesh_resource:
		print("No mesh resource assigned")
		return
	
	cleanup_multimesh_direct()  # Clean up any existing
	
	# Create MultiMesh resource
	multimesh_rid = RenderingServer.multimesh_create()
	
	# Setup MultiMesh
	RenderingServer.multimesh_set_mesh(multimesh_rid, mesh_resource.get_rid())
	#RenderingServer.multimesh_allocate_data(multimesh_rid, instance_count, RS.MULTIMESH_TRANSFORM_3D)
	
	# Create instance transforms
	#setup_instance_transforms()
	
	# Create rendering instance
	instance_rid = RenderingServer.instance_create()
	RenderingServer.instance_set_base(instance_rid, multimesh_rid)
	
	# Add to current scenario (viewport world)
	if scenario_rid.is_valid():
		RenderingServer.instance_set_scenario(instance_rid, scenario_rid)
	
	# Set transform
	var global_transform : Transform3D = Transform3D.IDENTITY
	RenderingServer.instance_set_transform(instance_rid, global_transform)

func setupColors( out_data : FlowData.Data ):
	var instance_count = out_data.size()
	var color : Color = node.settings.debug_color
	if node.settings.debug_modulate_by:
		var stream = out_data.findStream( node.settings.debug_modulate_by )
		if not stream:
			node.setError( "Attribute %s of type Float not found" %node. settings.debug_modulate_by )
			return
		if stream.data_type == FlowData.DataType.Float:
			var smod : PackedFloat32Array = stream.container
			for idx in range( instance_count ):
				RenderingServer.multimesh_instance_set_color( multimesh_rid, idx, color * smod[idx] )
			return
		elif stream.data_type == FlowData.DataType.Vector:
			var smod : PackedVector3Array = stream.container
			for idx in range( instance_count ):
				var c := smod[idx]
				RenderingServer.multimesh_instance_set_color( multimesh_rid, idx, color * Color( c.x, c.y, c.z, 1.0 ) )
			return
		else:
			node.setError( "Attribute %s must be of type float or vector to modulate" % node.settings.debug_modulate_by )
			
	for idx in range( instance_count ):
		RenderingServer.multimesh_instance_set_color( multimesh_rid, idx, color )

func setupDraw():
	var s = node.settings
	if !s.debug_enabled or s.disabled:
		return
		
	s.debug_bulk = clampi( s.debug_bulk, 0, node.generated_bulks.size() - 1)
	s.debug_output = clampi( s.debug_output, 0, node.generated_bulks[s.debug_bulk].size() - 1)
		
	var out_data : FlowData.Data = node.get_bulk_output(s.debug_bulk, s.debug_output)
	if not out_data || !out_data.hasStream( FlowData.AttrPosition ):
		print( "setupDebugDraw failed - out_data" )
		return
	var instance_count = out_data.size()
		
	if not multimesh_rid.is_valid() or RenderingServer.multimesh_get_instance_count(multimesh_rid) < instance_count:
		create_multimesh_direct()
		
	if not multimesh_rid.is_valid():
		print( "setupDebugDraw failed - multimesh_rid" )
		return
		
	var transforms := out_data.getTransformsStream()
	if transforms == null:
		print( "setupDebugDraw failed - positions/eulers" )
		return
	
	var debug_row = node.debug_row
	var allocated_count = instance_count
	if debug_row != -1 and debug_row < instance_count:
		allocated_count += 1
		
	var current_count = RenderingServer.multimesh_get_instance_count(multimesh_rid)
	if allocated_count != current_count:
		RenderingServer.multimesh_allocate_data(multimesh_rid, allocated_count, RenderingServer.MultimeshTransformFormat.MULTIMESH_TRANSFORM_3D, true )
	
	var time_start_loop = Time.get_ticks_usec()
	if node.settings.debug_mode == NodeSettings.eDebugMode.EXTENDS:
		var positions := transforms.positions
		var eulers := transforms.eulers
		var sizes := transforms.sizes
		for idx in range( instance_count ):
			var t := Transform3D( Basis.from_euler( eulers[idx] * PI / 180.0 ), positions[idx] ).scaled_local( sizes[idx] )
			RenderingServer.multimesh_instance_set_transform( multimesh_rid, idx, t)

	elif node.settings.debug_mode == NodeSettings.eDebugMode.ABSOLUTE:
		var abs_scale := Vector3.ONE * node.settings.debug_scale
		var positions := transforms.positions
		var eulers := transforms.eulers
		for idx in range( instance_count ):
			# Inlining the calls reduced from 40ms to 16ms
			var t := Transform3D( Basis.from_euler( eulers[idx] * PI / 180.0 ).scaled( abs_scale ), positions[idx] )
			RenderingServer.multimesh_instance_set_transform( multimesh_rid, idx, t)
	if node.settings.trace: print( "Debug.Loop: %f (%d)" % [ Time.get_ticks_usec() - time_start_loop, instance_count ] )
	setupColors( out_data )

	# Copy the transform and color at Nth and paste it at the end
	if allocated_count != instance_count:
		var t = RenderingServer.multimesh_instance_get_transform( multimesh_rid, debug_row)
		t = t.scaled_local( Vector3.ONE * 1.01 )
		RenderingServer.multimesh_instance_set_transform( multimesh_rid, instance_count, t)
		RenderingServer.multimesh_instance_set_color( multimesh_rid, instance_count, selection_color )
