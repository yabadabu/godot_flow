@tool
extends BaseTest

const GetBoundsNode = preload("res://addons/flow_nodes_editor/nodes/get_bounds.gd")

func test_path3d_bounds():
	var curve := Curve3D.new()
	curve.add_point( Vector3( -2.0, 1.0, 4.0 ) )
	curve.add_point( Vector3( 3.0, 5.0, -1.0 ) )

	var path := Path3D.new()
	path.curve = curve

	var node = GetBoundsNode.new()
	var aabb = node.get_bounds_of_node( path )
	assert_eq( aabb.position, Vector3( -2.0, 1.0, -1.0 ) )
	assert_eq( aabb.size, Vector3( 5.0, 4.0, 5.0 ) )

	path.free()

func test_unsupported_node_has_no_bounds():
	var spatial := Node3D.new()
	var node = GetBoundsNode.new()
	assert_null( node.get_bounds_of_node( spatial ) )
	spatial.free()
