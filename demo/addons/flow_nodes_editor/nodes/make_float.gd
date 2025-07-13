@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Make Float",
		"settings" : MakeFloatNodeSettings,
		"ins" : [], 
		"outs" : [{ "label" : "Out", "type" : TYPE_FLOAT }],
	}
	
func getTitle() -> String:
	return settings.out_name	

func execute( ctx : FlowData.EvaluationContext ):
	var value = getSettingValue( ctx, "value")
	var output := FlowData.Data.new()
	var container : PackedFloat32Array = output.addStream( settings.out_name, FlowData.DataType.Float )
	container.resize( 1 )
	container[0] = value
	set_output( 0, output )
