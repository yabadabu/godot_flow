extends Object
class_name FlowData

enum DataType {
	Bool,
	Float,
	Vector,
}

class EvaluationContext:
	var owner : Node3D

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
		return streams[ key0 ].container.size()
	
	func getContainerChecked( name : String, data_type : DataType ):
		var stream = streams.get( name, null )
		if stream and stream.data_type == data_type:
			return stream.container
		return null
		
	func findStream( name : String ):
		return streams.get( name, null )
	
	func registerStream( name : String, data_type : DataType, container ):
		streams[ name ] = { 
			"container" : container,
			"name" : name,
			"data_type" : data_type
		}
		print( "Registered stream %s : %s " % [ name, streams[ name ] ])
	
	func addStream( name : String, data_type : DataType):
		if not name:
			push_error("stream name can't be empty" )
			return null
		if streams.has( name ):
			push_error("Data already has stream named %s" % name )
			return null
		var new_container = newContainerOfType(data_type)
		registerStream( name, data_type, new_container )
		if size() > 0:
			new_container.resize( size() )
		return new_container
		
	func cloneStream( name : String ):
		if not streams.has( name ):
			push_error("cloneStream: Data does not have a stream named %s" % name )
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
		
	func filteredStream( old_stream : Dictionary, indices : PackedInt32Array ):
		var new_size : int = indices.size()
		match old_stream.data_type:
			
			DataType.Bool:
				var old_container : PackedByteArray = old_stream.container
				var new_container = PackedByteArray( )
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.Float:
				var old_container : PackedFloat32Array = old_stream.container
				var new_container = PackedFloat32Array( )
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.Vector:
				var old_container : PackedVector3Array = old_stream.container
				var new_container = PackedVector3Array(  )		
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
		return null

	func duplicate():
		# This is not a deep close, the packed*arrays are shared,
		# use cloneStream to create an independent cpy
		var s := Data.new()
		s.streams = streams.duplicate()
		return s
		
	func filter( indices : PackedInt32Array ):
		var new_data := Data.new()
		for old_stream in streams.values():
			var new_container = filteredStream( old_stream, indices )
			new_data.registerStream( old_stream.name, old_stream.data_type, new_container )
		return new_data

	func dump( title : String ):
		print( "== %s (%d streams) ==" % [title, streams.size()] )
		for stream in streams.values():
			print( "%s (%s) %d elems" % [ stream.name, stream.data_type, stream.container.size() ] )
			for data in stream.container:
				print( "  %s" % str(data ))
