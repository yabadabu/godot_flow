extends FlowNodeBase

@export var trans : Transform3D = Transform3D(Basis.IDENTITY, Vector3(0,0,1))

func getMeta() -> Dictionary :
	return {
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func getTitle() -> String:
	return "Transform"

func execute( ):
	var output = []
	var input_data = get_input(0)
	for data in input_data:
		var new_data = trans * data
		output.append( new_data )
	set_output( 0, output )
