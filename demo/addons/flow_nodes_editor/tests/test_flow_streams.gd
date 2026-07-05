@tool
extends BaseTest

func test_stream_names():
	var d = FlowData.Data.new()
	d.addCommonStreams(1)
	var prefix : String = "tx"
	d.addTRSStreams(1, prefix)
	
	var snames = d.streams.keys()
	assert_true( d.hasStream( FlowData.AttrPosition ) )
	assert_true( d.hasStream( FlowData.AttrRotation ) )
	assert_true( d.hasStream( FlowData.AttrSize ) )
	
	var tx_pos = prefix + "." + FlowData.AttrPosition
	var tx_rot = prefix + "." + FlowData.AttrRotation
	var tx_sz = prefix + "." + FlowData.AttrSize
	assert_true( d.hasStream( tx_pos ) )
	assert_true( d.hasStream( tx_rot ) )
	assert_true( d.hasStream( tx_sz ) )

	var s : Dictionary
	
	# Update position to 1.1, 2, 3
	s = d.findStream( FlowData.AttrPosition )
	assert_eq( s.container.size( ), 1 )
	s.container[0] = Vector3(1.1,2,3)
	# Update angles
	s = d.findStream( FlowData.AttrRotation )
	s.container[0] = Vector3(30,35,40)
	
	# Update tx.position to 11,22,33
	assert_true( d.hasStream( tx_pos ) )
	s = d.findStream( tx_pos )
	assert_eq( s.container.size( ), 1 )
	s.container[0] = Vector3(11,22,33)
	# Update tx.rotation
	s = d.findStream( tx_rot )
	s.container[0] = Vector3(70,71,72)

	# --------------------------------
	var kvs = [
		[ FlowData.AttrPosition + ".x", 1.1 ],
		[ tx_pos + ".x", 11 ],
		[ FlowData.AttrRotation + ".x", 30 ],
		[ "yaw", 35 ],
		[ tx_rot + ".x", 70 ],
		# upper case
		[ prefix + ".Yaw", 71 ],
		# Front
		[ "front.x", 0.49673175811768 ],
		[ "front.X", 0.49673175811768 ],
	]
	
	for kv in kvs:
		var sname = kv[0]
		var value = kv[1]
		s = d.findStream( sname )
		assert_eq( s.container.size( ), 1 )
		assert_approx_eq( s.container[0], value, 1e-5 )
	
