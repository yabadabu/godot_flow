extends FlowNodeBase

@export var value : float = 2.0

func getMeta() -> Dictionary :
	return {
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }, { "label" : "Removed" }],
	}

func getTitle() -> String:
	return "Spawn Meshes"

func execute( ):
	var output = []
	set_output( 0, output )
