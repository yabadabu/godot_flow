@tool
extends FlowNodeBase

@export_group("Make Bounds")
@export_custom(PROPERTY_HINT_LINK, "")
var size: Vector3 = Vector3(48.0, 1.0, 48.0)
@export var center: Vector3 = Vector3.ZERO

func _init():
	meta_node = {
		"title" : "Make Bounds",
		"category" : "Point Ops",
		"ins" : [], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates a single bounding point at center with size.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var out_data := FlowData.Data.new()
	out_data.addCommonStreams(1)
	
	var spos = out_data.getVector3Container(FlowData.AttrPosition)
	var ssize = out_data.getVector3Container(FlowData.AttrSize)
	
	var sz = getSettingValue(ctx, "size", Vector3(48.0, 1.0, 48.0))
	var c = getSettingValue(ctx, "center", Vector3.ZERO)
	
	spos[0] = c
	ssize[0] = sz
	
	set_output(0, out_data)
