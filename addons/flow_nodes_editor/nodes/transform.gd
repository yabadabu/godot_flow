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
	var in_data = get_input(0)
	var out_data = in_data.duplicate()
	var spos = out_data.cloneStream( "position" )
	var trans = settings.trans
	for i in spos.size():
		spos[i] = trans * spos[i]
	set_output( 0, out_data )
