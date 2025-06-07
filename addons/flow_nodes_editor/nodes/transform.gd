@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Transform",
		"settings" : TransformNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( ):
	var output = []
	var input_data = get_input(0)
	var trans = settings.trans
	for data in input_data:
		var new_data = trans * data
		output.append( new_data )
	set_output( 0, output )
