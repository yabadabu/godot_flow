extends Object
class_name FlowData

enum DataType {
	Bool,
	Float,
	Vector,
}

class Data:
	var streams : Dictionary = {}

	func newContainerOfType( data_type : DataType ):
		match data_type:
			DataType.Bool:
				return PackedByteArray()
			DataType.Float:
				return PackedFloat32Array()
			DataType.Vector:
				return PackedVector3Array()
		return null
	
	func numFields() -> int:
		return streams.size()
		
	func size() -> int:
		var key0 = streams.keys()[0]
		return streams[ key0 ].size()
	
	func addStream( data_type : DataType, name : String ):
		
		if streams.has( name ):
			push_error("Data already has stream named %s" % name )
			return null
		var new_container = newContainerOfType(data_type)
		streams[ name ] = { 
			"container" : new_container,
			"name" : name,
			"data_type" : data_type
		}
		return new_container
		
	func cloneStream( name : String ):
		if not streams.has( name ):
			push_error("Data does not have a stream named %s" % name )
			return null
		var prev_stream = streams[ name ]
		var new_container
		match prev_stream.data_type:
			DataType.Bool:
				new_container = PackedByteArray( prev_stream.container )
			DataType.Float:
				new_container = PackedFloat32Array( prev_stream.container )
			DataType.Vector:
				new_container = PackedVector3Array( prev_stream.container )		
		prev_stream.container = new_container
		return new_container

	func duplicate():
		var s = Data.new()
		s.streams = streams.duplicate()
		return s

	func dump( title : String ):
		print( "== %s" % title)
		for stream in streams.values():
			print( "%s (%s) %d elems" % [ stream.name, stream.data_type, stream.container.size() ] )
			for data in stream.container:
				print( "  %s" % str(data ))
