@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Transform",
		"settings" : TransformNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	var spos : PackedVector3Array = out_data.cloneStream( FlowData.AttrPosition )
	var trans = settings.trans
	for i in spos.size():
		spos[i] = trans * spos[i]
	set_output( 0, out_data )
