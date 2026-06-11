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
		"aliases" : ["Asset List", "Weighted Assets", "Mesh Entries"],
		"category" : "Input",
	}

const discarded_props = {
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
		if asset == null:
			continue
		# print( "=== %s (x %d)" % [ asset, count ] )
		for prop in asset.get_property_list():
			if !(prop.usage & PROPERTY_USAGE_EDITOR) || !(prop.usage & PROPERTY_USAGE_STORAGE):
				continue
			if discarded_props.has( prop.name ):
				continue
			if settings.trace:
				print( "Prop: %d Name:%s" % [ prop.type, prop.name ])
			var new_type = FlowData.DataType.Invalid
			match prop.type:
				TYPE_BOOL:
					new_type = FlowData.DataType.Bool
				TYPE_INT:
					new_type = FlowData.DataType.Int
				TYPE_FLOAT:
					new_type = FlowData.DataType.Float
				TYPE_VECTOR3:
					new_type = FlowData.DataType.Vector
				TYPE_COLOR:
					new_type = FlowData.DataType.Vector
				TYPE_STRING:
					new_type = FlowData.DataType.String
				TYPE_OBJECT:
					new_type = FlowData.DataType.Resource
				_:
					push_error("Property %s has unsupported type (%d)" % [ prop.name, prop.type ])
			if new_type == FlowData.DataType.Invalid:
				continue
			if new_streams.has( prop.name ) and new_streams[ prop.name ] != new_type:
				push_warning("Assets: property '%s' is exposed with different types across assets — the last type wins" % prop.name)
			new_streams[ prop.name ] = new_type

	for prop_name in new_streams.keys():
		var prop_type = new_streams[ prop_name ]
		if settings.trace:
			print( "Stream: Type:%d Name:%s" % [ prop_type, prop_name ])
		match prop_type:

			FlowData.DataType.Bool:
				var container : PackedByteArray = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = 1 if _asset_value( idx, prop_name, false ) else 0

			FlowData.DataType.Int:
				var container : PackedInt32Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = int(_asset_value( idx, prop_name, 0 ))

			FlowData.DataType.Float:
				var container : PackedFloat32Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = float(_asset_value( idx, prop_name, 0.0 ))

			FlowData.DataType.String:
				var container : PackedStringArray = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = str(_asset_value( idx, prop_name, "" ))

			FlowData.DataType.Vector:
				var container : PackedVector3Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					var value = _asset_value( idx, prop_name, Vector3.ZERO )
					if typeof( value ) == TYPE_COLOR:
						container[idx] = Vector3( value.r, value.g, value.b )
					elif typeof( value ) == TYPE_VECTOR3:
						container[idx] = value
					else:
						container[idx] = Vector3.ZERO

			_:
				var container : Array = output.addStream( prop_name, prop_type )
				container.resize( count )
				for idx in range(count):
					container[idx] = _asset_value( idx, prop_name, null )
					#print( "%s[%d] = %s" % [ prop_name, idx, container[idx]])
	set_output( 0, output )

# Heterogeneous asset lists may miss a property on some entries (and entries
# may be null) — fall back to a per-type default instead of writing null into
# a Packed container (runtime error).
func _asset_value( idx : int, prop_name : String, default_value ):
	var asset = settings.assets[idx]
	if asset == null:
		return default_value
	var value = asset.get( prop_name )
	if value == null:
		return default_value
	return value
