@tool
extends FlowNodeBase

@export var value : float = 2.0

func getMeta() -> Dictionary :
	return {
		"title" : "Spawn Meshes",
		"settings" : SpawnMeshesNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }, { "label" : "Removed" }],
	}

func isFinal() -> bool:
	return true

func execute( ):
	var input = get_input(0)
	if !input:
		print( "Input is invalid")
		return
	input.dump( "At spawn meshes" )
	#for stream in input.streams.values():
		#print( "%s (%s) %d elems" % [ stream.name, stream.data_type, stream.container.size() ] )
		#for data in stream.container:
			#print( "  %s" % str(data ))
	#var output = []
	#set_output( 0, output )
