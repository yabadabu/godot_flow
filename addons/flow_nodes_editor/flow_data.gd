extends Object
class_name FlowData

enum DataType {
	Bool,
	Float,
	Vector,
	String,
	Resource,
}

const AttrPosition : StringName = &"position"
const AttrRotation : StringName = &"rotation"

class EvaluationContext:
	var owner : Node3D
	var eval_id : int = 0

static func basisToEuler( basis : Basis ) -> Vector3:
	var euler = basis.get_euler() 
	euler.x = rad_to_deg( euler.x )
	euler.y = rad_to_deg( euler.y )
	euler.z = rad_to_deg( euler.z )
	return euler

static func eulerToBasis( euler : Vector3) -> Basis:
	euler.x = deg_to_rad( euler.x )
	euler.y = deg_to_rad( euler.y )
	euler.z = deg_to_rad( euler.z )
	return Basis.from_euler( euler )

class TransformsStream:
	var positions : PackedVector3Array
	var eulers : PackedVector3Array
	#var sizes : PackedVector3Array
	
	func atIndex( id: int ) -> Transform3D:
		var basis := FlowData.eulerToBasis( eulers[id] )
		return Transform3D( basis, positions[id] )

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
			DataType.Resource:
				return Array([], TYPE_OBJECT, "Resource", null)
			DataType.String:
				return Array([], TYPE_STRING, "", null)
		return null
	
	func numFields() -> int:
		return streams.size()
		
	func size() -> int:
		if streams.size() == 0:
			return 0
		var key0 = streams.keys()[0]
		return streams[ key0 ].container.size()
	
	func hasStream( name : StringName ) -> bool:
		return streams.has( name )
	
	func getContainerChecked( name : String, data_type : DataType ):
		var stream = streams.get( name, null )
		if stream and stream.data_type == data_type:
			return stream.container
		return null
		
	# converts 'Yaw' into "Rotation.Y" 
	func translateStreamName( name : String ):
		if name == "Yaw":
			return "%s.Y" % FlowData.AttrRotation
		if name == "Pitch":
			return "%s.X" % FlowData.AttrRotation
		if name == "Roll":
			return "%s.Z" % FlowData.AttrRotation
		return name
		
	func getSubStreamIndex(  sub_comp : String ):
		if sub_comp == "X":
			return 0
		elif sub_comp== "Y":
			return 1
		elif sub_comp == "Z":
			return 2
		return -1
	
	func getSubStream( stream : Dictionary, sub_comp : String ):
		var subcomp_idx = getSubStreamIndex( sub_comp )
		if subcomp_idx == -1:
			push_error( "Invalid sub_stream name %s" % sub_comp )
			return null
		if stream.data_type != DataType.Vector:
			return "getSubStream.Parent stream must be of type Vector"
			return null
		var big_container = stream.container
		var new_container = PackedFloat32Array()
		new_container.resize( big_container.size() )
		for idx in range( big_container.size() ):
			new_container[idx] = big_container[idx][ subcomp_idx ]
		return {
			"data_type" : DataType.Float,
			"container" : new_container,
			"name" : "%s.%s" % [ stream.name, sub_comp ]
		}
		
	func setSubStream( stream : Dictionary, sub_comp : String, sub_container  ):
		var subcomp_idx = getSubStreamIndex( sub_comp )
		if subcomp_idx == -1:
			return "Invalid sub stream name %s" % sub_comp
		if stream.data_type != DataType.Vector:
			return "setSubStream.Parent stream must be of type Vector"
		var big_container = stream.container
		if sub_container.size() != big_container.size():
			return "Container sizes do not match (%d vs %d)" % [sub_container.size(), big_container.size()]
		for idx in range( big_container.size() ):
			big_container[idx][ subcomp_idx ] = sub_container[idx]
		
	func findStream( name : String ):
		name = translateStreamName( name )
		var parts = name.split( "." )
		if parts.size() == 2:
			#print( "findStream(%s) => %s" % [ name, parts])
			var s0 = streams.get( parts[0], null )
			if s0 == null:
				push_error( "Failed to find stream root %s" % parts[0] )
				return null
			#print( "searching (%s) in %s" % [ parts[1], s0])
			return getSubStream( s0, parts[1] )
		elif parts.size() > 2:
			return null
		return streams.get( name, null )
	
	func registerStream( name : String, data_type : DataType, container ):
		if not name:
			push_error("registerStream name can't be empty" )
			return null
		name = translateStreamName( name )
		var parts = name.split( "." )
		if parts.size() == 2:
			var s0 = streams.get( parts[0], null )
			if s0 == null:
				return "Failed to find stream %s" % parts[0] 
			return setSubStream( s0, parts[1], container )
		elif parts.size() > 2:
			return "Too many '.' in stream name"
		else:
			streams[ name ] = { 
				"container" : container,
				"name" : name,
				"data_type" : data_type
			}
		#print( "Registered stream %s : %s " % [ name, streams[ name ] ])
		return null
	
	func addStream( name : String, data_type : DataType):
		if not name:
			push_error("stream name can't be empty" )
			return null
		var sz := size()
		var new_container = newContainerOfType(data_type)
		registerStream( name, data_type, new_container )
		if sz:
			new_container.resize( sz )
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
			_:
				new_container = prev_stream.container.duplicate()	
		prev_stream.container = new_container
		return new_container
		
	func filteredStream( old_stream : Dictionary, indices : PackedInt32Array ):
		var new_size : int = indices.size()
		match old_stream.data_type:
			
			DataType.Bool:
				var old_container : PackedByteArray = old_stream.container
				var new_container := PackedByteArray( )
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.Float:
				var old_container : PackedFloat32Array = old_stream.container
				var new_container := PackedFloat32Array( )
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.Vector:
				var old_container : PackedVector3Array = old_stream.container
				var new_container := PackedVector3Array(  )		
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.String:
				var old_container : Array[ String ] = old_stream.container
				var new_container : Array[ String ] = []
				new_container.resize( new_size )
				for idx in range( new_size ):
					new_container[idx] = old_container[ indices[idx] ]
				return new_container
				
			DataType.Resource:
				var old_container : Array[ Resource ] = old_stream.container
				var new_container : Array[ Resource ] = []
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

	func addCommonStreams( num_points : int ):
		var spos = addStream( FlowData.AttrPosition, FlowData.DataType.Vector )
		spos.resize( num_points )
		var srot = addStream( FlowData.AttrRotation, FlowData.DataType.Vector )
		srot.resize( num_points )

	func getVector3Container( stream_name : StringName ) -> PackedVector3Array:
		return getContainerChecked( stream_name, DataType.Vector )

	func getTransformsStream() -> TransformsStream:
		var trs := TransformsStream.new()
		trs.positions = getVector3Container( AttrPosition )
		if trs.positions == null:
			return null
		trs.eulers = getVector3Container( AttrRotation )
		if trs.eulers == null:
			return null	
		return trs
