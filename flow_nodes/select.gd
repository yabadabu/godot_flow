extends FlowNodeBase

@export var ratio : float = 0.1

func getMeta() -> Dictionary :
	return {
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func getTitle() -> String:
	return "Select"

func execute( ):
	var input_data = get_input(0)
	var output = []
	for data in input_data:
		if rng.randf() < ratio:
			output.append( data )
	set_output( 0, output )
