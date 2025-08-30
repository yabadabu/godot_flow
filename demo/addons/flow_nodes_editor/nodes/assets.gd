@tool
extends FlowNodeBase
class_name FlowNodeAssets

func _init():
	meta_node = {
		"title" : "Assets",
		"settings" : AssetsNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"hide_inputs" : true,
		"tooltip" :"Generates a list of assets.\nUseful in combination with the Match And Set node, this node generates a list of meshes with some attribute/tag and weight assigned.",
	}
	
const discardted_props = {
	"resource_local_to_scene" : 1,
	"resource_name" : 1,
	"metadata/_custom_type_script" : 1,
	"script" : 1,
	"data" : 1,
}

func execute( _ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var new_streams = {}
	
	var count = settings.assets.size()
	for idx in range(count):
		var asset = settings.assets[idx]
		# print( "=== %s (x %d)" % [ asset, count ] )
		for prop in asset.get_property_list():
			if !(prop.usage & PROPERTY_USAGE_EDITOR) || !(prop.usage & PROPERTY_USAGE_STORAGE):
				continue
			if discardted_props.has( prop.name ):
				continue
			if settings.trace:
				print( "Prop: %d Name:%s" % [ prop.type, prop.name ])				
			match prop.type:
				TYPE_BOOL:
					new_streams[ prop.name ] = FlowData.DataType.Bool
				TYPE_INT:
					new_streams[ prop.name ] = FlowData.DataType.Int
				TYPE_FLOAT:
					new_streams[ prop.name ] = FlowData.DataType.Float
				TYPE_VECTOR3:
					new_streams[ prop.name ] = FlowData.DataType.Vector
				TYPE_COLOR:
					new_streams[ prop.name ] = FlowData.DataType.Vector
				TYPE_STRING:
					new_streams[ prop.name ] = FlowData.DataType.String
				TYPE_OBJECT:
					new_streams[ prop.name ] = FlowData.DataType.Resource
				_:
					push_error("Property %s has unsupported type (%d)" % [ prop.name, prop.type ])

	for prop_name in new_streams.keys():
		var prop_type = new_streams[ prop_name ]
		if settings.trace:
			print( "Stream: Type:%d Name:%s" % [ prop_type, prop_name ])
		match prop_type:
			
			FlowData.DataType.Bool:
				var container : PackedByteArray = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					
			FlowData.DataType.Int:
				var container : PackedInt32Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					
			FlowData.DataType.Float:
				var container : PackedFloat32Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					
			FlowData.DataType.String:
				var container : PackedStringArray = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					
			FlowData.DataType.Vector:
				var container : PackedVector3Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					var value = settings.assets[idx].get( prop_name )
					if typeof( value ) == TYPE_COLOR:
						container[idx] = Vector3( value.r, value.g, value.b )
					else:
						container[idx] = value
					
			_:
				var container : Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					#print( "%s[%d] = %s" % [ prop_name, idx, container[idx]])
	set_output( 0, output )
