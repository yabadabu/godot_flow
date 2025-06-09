@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Assets",
		"settings" : AssetsNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generates a list of assets",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var new_streams = {}
	
	var count = settings.assets.size()
	for idx in range(count):
		var asset = settings.assets[idx]
		print( "=== %s (x %d)" % [ asset, count ] )
		for prop in asset.get_property_list():
			if prop.usage != 6:
				continue
			if prop.name == "resource_local_to_scene" || prop.name == "resource_name" || prop.name == "metadata/_custom_type_script":
				continue
			print( " %s " % prop )
			if prop.type == TYPE_FLOAT:
				#print( "%s is a float" % prop.name)
				new_streams[ prop.name ] = FlowData.DataType.Float
			elif prop.type == typeof(Resource):
				#print( "%s is a resource" % prop.name)
				new_streams[ prop.name ] = FlowData.DataType.DTResource

	for prop_name in new_streams.keys():
		var prop_type = new_streams[ prop_name ]
		if prop_type == FlowData.DataType.Float:
			var container : PackedFloat32Array = output.addStream( prop_name, prop_type )
			container.resize( count )
			for idx in range(count):
				var asset = settings.assets[idx]
				var value = asset.get( prop_name )
				#print( "FloatProp:%s, Idx:%d -> %s" % [ prop_name, idx, str(value)] )
				container[idx] = value
		else:
			var container : Array = output.addStream( prop_name, prop_type )
			container.resize( count )
			for idx in range(count):
				var asset = settings.assets[idx]
				var value = asset.get( prop_name )
				#print( "ObjProp:%s, Idx:%d -> %s" % [ prop_name, idx, str(value)] )
				container[idx] = value
	set_output( 0, output )
