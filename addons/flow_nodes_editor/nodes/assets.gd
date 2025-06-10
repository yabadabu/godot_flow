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
	
const discardted_props = {
	"resource_local_to_scene" : 1,
	"resource_name" : 1,
	"metadata/_custom_type_script" : 1,
	"script" : 1,
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
			# print( " %s " % prop )
			match prop.type:
				TYPE_FLOAT:
					new_streams[ prop.name ] = FlowData.DataType.Float
				TYPE_STRING:
					new_streams[ prop.name ] = FlowData.DataType.DTString
				TYPE_OBJECT:
					new_streams[ prop.name ] = FlowData.DataType.DTResource
				_:
					push_error("Property %s has unsupported type (%d)" % [ prop.name, prop.type ])

	for prop_name in new_streams.keys():
		var prop_type = new_streams[ prop_name ]
		match prop_type:
			FlowData.DataType.Float:
				var container : PackedFloat32Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
			_:
				var container : Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = settings.assets[idx].get( prop_name )
					
	set_output( 0, output )
