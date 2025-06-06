@tool
extends FlowNodeBase

@export var value : float = 2.0

func getMeta() -> Dictionary :
	return {
		"title" : "Spawn Meshes",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }, { "label" : "Removed" }],
	}

func isFinal() -> bool:
	return true

func execute( ):
	var input = get_input(0)
	for data in input:
		print( "Spawning at %s" % str(data) )
	var output = []
	set_output( 0, output )
